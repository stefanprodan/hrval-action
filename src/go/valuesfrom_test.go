package main

import (
	"reflect"
	"testing"
)

func Test_parseHelmRelease(t *testing.T) {
	// given
	yaml := `
metadata:
  namespace: default-namespace
spec:
  valuesFrom:
    - configMapKeyRef:
        name: podinfo-values1
        namespace: test-namespace
        key: additionalValues
    - secretKeyRef:
        name: podinfo-secret1
        optional: true`

	// when
	helmRelease := parseHelmRelease([]byte(yaml))

	// then
	expectedValuesFromConfigMap := ResourceKeySelector{
		Name:      "podinfo-values1",
		Namespace: "test-namespace",
		Key:       "additionalValues",
	}
	expectedValuesFromSecret := ResourceKeySelector{
		Name:     "podinfo-secret1",
		Optional: true,
	}

	if !reflect.DeepEqual(*helmRelease.Spec.ValuesFrom[0].ConfigMapKeyRef, expectedValuesFromConfigMap) {
		t.Errorf("ConfigMapKeyRef = %v, want %v", *helmRelease.Spec.ValuesFrom[0].ConfigMapKeyRef, expectedValuesFromConfigMap)
	}
	if !reflect.DeepEqual(*helmRelease.Spec.ValuesFrom[1].SecretKeyRef, expectedValuesFromSecret) {
		t.Errorf("SecretKeyRef = %v, want %v", *helmRelease.Spec.ValuesFrom[1].SecretKeyRef, expectedValuesFromSecret)
	}
}

func Test_getValuesFrom(t *testing.T) {
	// given
	var configMapRef = ResourceKeySelector{
		Name:      "cm1",
		Namespace: "ns1",
		Key:       "myvalues.yaml",
	}
	var secretRef = ResourceKeySelector{
		Name:     "secret1",
		Optional: true,
	}

	valuesFromSource := []ValuesFromSource{
		{ConfigMapKeyRef: &configMapRef},
		{SecretKeyRef: &secretRef},
	}
	var helmRelease = HelmRelease{
		Metadata: map[string]interface{}{
			"namespace": "default-namespace",
		},
		Spec: HelmReleaseSpec{
			ValuesFrom: valuesFromSource,
		},
	}

	// when
	valuesFrom := getValuesFrom(helmRelease)

	// then
	expectedValuesFrom := []ValuesFrom{
		{
			Type:      ConfigMap,
			Name:      "cm1",
			Namespace: "ns1",
			Key:       "myvalues.yaml",
			Optional:  false,
		},
		{
			Type:      Secret,
			Name:      "secret1",
			Namespace: "default-namespace",
			Key:       "values.yaml",
			Optional:  true,
		},
	}

	if !reflect.DeepEqual(valuesFrom, expectedValuesFrom) {
		t.Errorf("getValuesFrom() = %v, want %v", valuesFrom, expectedValuesFrom)
	}
}
