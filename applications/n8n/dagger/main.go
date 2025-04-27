// A generated module for N8N functions
//
// This module has been generated via dagger init and serves as a reference to
// basic module structure as you get started with Dagger.
//
// Two functions have been pre-created. You can modify, delete, or add to them,
// as needed. They demonstrate usage of arguments and return types using simple
// echo and grep commands. The functions can be called from the dagger CLI or
// from one of the SDKs.
//
// The first line in this comment block is a short description line and the
// rest is a long description with more detail on the module's purpose or usage,
// if appropriate. All modules should have a short description.

package main

import (
	"context"
	"dagger/n-8-n/internal/dagger"
	"fmt"
	"log"
	"time"
)

type N8N struct {
	// +private
	Source *dagger.Directory
}

const (
	REPLICATED_APP = "gerard-n8n"
	CHART_DIR      = "charts/n8n"
)

func New(
	// Project source directory
	//
	// +defaultPath="."
	source *dagger.Directory) *N8N {
	return &N8N{
		Source: source,
	}
}

func (m *N8N) CreateReplicatedRelease(ctx context.Context, token *dagger.Secret, version, channel string) (string, error) {
	versionStr := m.generateVersion(ctx, version)
	packagedDir := m.PrepareReplicatedRelease(ctx, versionStr)
	return dag.Container().
		From("replicated/vendor-cli:latest").
		WithDirectory("/src", packagedDir).
		WithEnvVariable("REPLICATED_APP", REPLICATED_APP).
		WithSecretVariable("REPLICATED_API_TOKEN", token).
		WithExec([]string{"/replicated", "release", "create", "--yaml-dir", "/src", "--promote", channel, "--version", version, "--ensure-channel"}).
		Stdout(ctx)
}

func (m *N8N) DownloadLicense(ctx context.Context, token *dagger.Secret, channel string) *dagger.File {
	// create customer and download license
	customerName := fmt.Sprintf("%s-customer", channel)
	return dag.Container().
		From("replicated/vendor-cli:latest").
		WithEnvVariable("REPLICATED_APP", REPLICATED_APP).
		WithSecretVariable("REPLICATED_API_TOKEN", token).
		WithExec([]string{"/replicated", "customer", "create", "--name", customerName, "--channel", channel}).
		WithExec([]string{"/replicated", "customer", "download-license", "--customer", customerName, "--output", "license.yaml"}).
		File("license.yaml")
}

func (m *N8N) PrepareReplicatedRelease(ctx context.Context, version string) *dagger.Directory {
	releaseDir := m.Source.Directory("replicated")

	// lint chart
	_, err := m.Lint(ctx)
	if err != nil {
		log.Fatalf("Failed to lint Helm chart: %v", err)
	}

	// package Helm chart
	appHelmChart := m.Package(ctx, version)
	appHelmChartName, _ := appHelmChart.Name(ctx)

	// update KOTS HelmChart CR version
	baseContainer := m.Base()
	return baseContainer.
		WithDirectory("/src", releaseDir).
		WithWorkdir("/src").
		WithExec([]string{"apk", "add", "yq"}).
		WithExec([]string{"yq", "-i", fmt.Sprintf(".spec.chart.chartVersion=\"%s\"", version), "kots-chart.yaml"}).
		WithFile(appHelmChartName, appHelmChart).
		Directory("/src")
}

func (m *N8N) Base() *dagger.Container {
	return dag.Container().From("alpine:latest")
}

// Lint the Helm chart
func (m *N8N) Lint(ctx context.Context) (string, error) {
	chart := m.chart()
	return chart.Lint().Stdout(ctx)
}

// Package the Helm chart
func (m *N8N) Package(ctx context.Context, version string) *dagger.File {
	chart := m.chart()
	return chart.Package(dagger.HelmChartPackageOpts{
		Version:          version,
		AppVersion:       version,
		DependencyUpdate: true,
	}).File()
}

func (m *N8N) chart() *dagger.HelmChart {
	chart := m.Source.Directory(CHART_DIR)
	return dag.Helm(dagger.HelmOpts{
		Version: "3.17.1",
	}).Chart(chart)
}

// Generates a version string based on the current date, branch name, and commit hash
func (m *N8N) generateVersion(ctx context.Context, version string) string {
	date := time.Now().Format("20060102-150405")
	return fmt.Sprintf("%s-%s", version, date)
}
