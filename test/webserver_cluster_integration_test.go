package test

import (
	"fmt"
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/http-helper"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestWebserverClusterIntegration(t *testing.T) {
	t.Parallel()

	uniqueID := random.UniqueId()
	clusterName := fmt.Sprintf("test-cluster-%s", uniqueID)

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		// Adjusted path to match project structure
		TerraformDir: "../modules/webserver-cluster",
		Vars: map[string]interface{}{
			"environment":      "dev",
			"min_size":         1,
			"max_size":         2,
			"desired_capacity": 1,
			"vpc_cidr":         "10.0.0.0/16",
			"vpc_name":         clusterName,
			"public_subnets": map[string]interface{}{
				"sub-1": map[string]any{"cidr": "10.0.1.0/24", "az": "us-east-1a"},
			},
			"server_port": 80,
		},
	})

	// Always destroy at the end, even if assertions fail
	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	albDnsName := terraform.Output(t, terraformOptions, "alb_dns_name")
	url := fmt.Sprintf("http://%s", albDnsName)

	// Retry for up to 5 minutes — ALB takes time to register instances
	http_helper.HttpGetWithRetryWithCustomValidation(
		t,
		url,
		nil,
		30,
		10*time.Second,
		func(status int, body string) bool {
			return status == 200 && len(body) > 0
		},
	)

	// Assert the output is defined and non-empty
	assert.NotEmpty(t, albDnsName, "ALB DNS name should not be empty")
}
