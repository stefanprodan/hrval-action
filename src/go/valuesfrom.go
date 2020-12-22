package main

import (
	"bytes"
	"encoding/base64"
	"fmt"
	"io/ioutil"
	"log"
	"os"
	"path/filepath"
	"strings"

	"github.com/google/uuid"
	"gopkg.in/yaml.v2"
)

func main() {
	argsWithoutProg := os.Args[1:]
	helmReleaseFilePath := argsWithoutProg[0]
	valuesDirPath := argsWithoutProg[1]
	tempDirPath := argsWithoutProg[2]

	if file, err := os.Stat(valuesDirPath); os.IsNotExist(err) || !file.IsDir() {
		log.Fatalf("Directory with valuesFrom not found or is not a directory: '%v'", valuesDirPath)
	}

	fileContent, readError := ioutil.ReadFile(helmReleaseFilePath)
	if readError != nil {
		log.Fatalf("error: %v", readError)
	}

	helmRelease := parseHelmRelease(fileContent)
	valuesFromSlice := getValuesFrom(helmRelease)
	var tempFilesWithValuesPaths = make([]string, 0, len(valuesFromSlice))

	for _, valuesFrom := range valuesFromSlice {
		readValues, err := findValues(valuesDirPath, valuesFrom)
		if err != nil {
			if valuesFrom.Optional {
				continue
			} else {
				log.Fatalf("Could not find file for non-optional valuesFrom: %v\n", valuesFrom)
			}
		}
		tempValuesFilePath := prepareTemporaryValuesFile(tempDirPath, readValues)
		tempFilesWithValuesPaths = append(tempFilesWithValuesPaths, tempValuesFilePath)
	}

	if len(tempFilesWithValuesPaths) > 0 {
		joinedValuesFiles := " -f " + strings.Join(tempFilesWithValuesPaths, " -f ")
		fmt.Print(joinedValuesFiles)
	}
}

func prepareTemporaryValuesFile(tempDirPath string, values string) string {
	randomUUID, _ := uuid.NewUUID()
	tmpValuesFilePath := tempDirPath + "/" + randomUUID.String() + ".yaml"
	tmpValuesFile, err := os.Create(tmpValuesFilePath)
	if err != nil {
		log.Fatalf("Unable to create temp value file: %v", tmpValuesFilePath)
	}
	if _, err = tmpValuesFile.WriteString(values); err != nil {
		log.Fatalf("Unable to write to temp value file: %v", tmpValuesFilePath)
	}
	_ = tmpValuesFile.Close()

	return tmpValuesFilePath
}

func getValuesFrom(helmRelease HelmRelease) []ValuesFrom {
	var valuesFrom = make([]ValuesFrom, 0, len(helmRelease.Spec.ValuesFrom))
	for _, valuesFromSource := range helmRelease.Spec.ValuesFrom {
		var reference *ResourceKeySelector
		var valuesFromType ValuesFromType
		switch {
		case valuesFromSource.ConfigMapKeyRef != nil:
			reference = valuesFromSource.ConfigMapKeyRef
			valuesFromType = ConfigMap
		case valuesFromSource.SecretKeyRef != nil:
			reference = valuesFromSource.SecretKeyRef
			valuesFromType = Secret
		default:
			continue
		}

		key := "values.yaml"
		if reference.Key != "" {
			key = reference.Key
		}
		namespace := helmRelease.Metadata["namespace"]
		if reference.Namespace != "" {
			namespace = reference.Namespace
		}

		valuesFrom = append(valuesFrom, newValuesFrom(valuesFromType, reference.Name, key, fmt.Sprintf("%v", namespace), reference.Optional))
	}
	return valuesFrom
}

func parseHelmRelease(fileContent []byte) HelmRelease {
	release := HelmRelease{}
	err := yaml.Unmarshal(fileContent, &release)
	if err != nil {
		log.Fatalf("error: %v", err)
	}
	return release
}

func findValues(valuesDirPath string, valuesFrom ValuesFrom) (string, error) {
	var fileList []string
	err := filepath.Walk(valuesDirPath, func(path string, info os.FileInfo, err error) error {
		if info.Mode().IsRegular() {
			fileList = append(fileList, path)
		}
		return nil
	})
	if err != nil {
		log.Fatalf("error: %v", err)
	}

	// fmt.Printf("Files for 'valuesFrom' found: %v\n", fileList)
	for _, filePath := range fileList {
		file, err := ioutil.ReadFile(filePath)
		if err != nil {
			log.Fatalf("error: %v", err)
		}
		var resource ValuesFromResource
		dec := yaml.NewDecoder(bytes.NewReader(file))
		for dec.Decode(&resource) == nil {
			// fmt.Printf("Resource with type %v and name %v found\n", resource.Kind, resource.Metadata["name"])
			if resource.Kind == valuesFrom.Type && resource.Metadata["name"] == valuesFrom.Name {
				values := resource.Data[valuesFrom.Key]
				if resource.Kind == Secret {
					var valuesBytes []byte
					valuesBytes, _ = base64.StdEncoding.DecodeString(values)
					values = string(valuesBytes)
				}
				return values, nil
			}
		}
	}
	return "", &fileWithValuesNotFoundError{}
}

type fileWithValuesNotFoundError struct {
}

func (e *fileWithValuesNotFoundError) Error() string {
	return "No files for ValuesFrom found"
}

// HelmRelease as specified by Flux
type HelmRelease struct {
	Spec     HelmReleaseSpec        `yaml:"spec"`
	Metadata map[string]interface{} `yaml:"metadata"`
}

// HelmReleaseSpec : "spec" in HelmRelease
type HelmReleaseSpec struct {
	ValuesFrom []ValuesFromSource `yaml:"valuesFrom,omitempty"`
}

// ValuesFromSource : "valuesFrom" in HelmRelease
type ValuesFromSource struct {
	ConfigMapKeyRef *ResourceKeySelector `yaml:"configMapKeyRef,omitempty"`
	SecretKeyRef    *ResourceKeySelector `yaml:"secretKeyRef,omitempty"`
}

// ResourceKeySelector : "configMapKeyRef" or "secretKeyRef" in HelmRelease
type ResourceKeySelector struct {
	Name      string `yaml:"name"`
	Key       string `yaml:"key"`
	Namespace string `yaml:"namespace"`
	Optional  bool   `yaml:"optional"`
}

// ValuesFrom describes where to look for additional values for HelmRelease
type ValuesFrom struct {
	Type      ValuesFromType
	Name      string
	Namespace string
	Key       string
	Optional  bool
}

// ValuesFromType describes if "valuesFrom" is referencing ConfigMap or Secret
type ValuesFromType string

const (
	// ConfigMap referencing valuesFrom
	ConfigMap ValuesFromType = "ConfigMap"
	// Secret referencing valuesFrom
	Secret = "Secret"
)

func newValuesFrom(valuesFromType ValuesFromType, name string, key string, namespace string, optional bool) ValuesFrom {
	return ValuesFrom{
		Type:      valuesFromType,
		Name:      name,
		Namespace: namespace,
		Key:       key,
		Optional:  optional,
	}
}

// ValuesFromResource is ConfigMap or Secret for ValuesFrom to read
type ValuesFromResource struct {
	Kind     ValuesFromType         `yaml:"kind"`
	Metadata map[string]interface{} `yaml:"metadata"`
	Data     map[string]string      `yaml:"data"`
}
