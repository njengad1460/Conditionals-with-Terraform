package test

import (
	"fmt"
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/http-helper"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
)

func TestFullStackEndToEnd(t *testing.T) {
	t.Parallel()

	uniqueID := random.UniqueId()

	appOptions := &terraform.Options{
		TerraformDir: "../modules/webserver-cluster",
		Vars: map[string]interface{}{
			"environment":      "dev",
			"min_size":         1,
			"max_size":         2,
			"desired_capacity": 1,
			"vpc_cidr":         "10.0.0.0/16",
			"vpc_name":         fmt.Sprintf("test-app-%s", uniqueID),
			"public_subnets": map[string]interface{}{
				"sub-1": map[string]interface{}{"cidr": "10.0.1.0/24", "az": "us-east-1a"},
			},
			"server_port": 80,
		},
	}
	defer terraform.Destroy(t, appOptions)
	terraform.InitAndApply(t, appOptions)

	albDnsName := terraform.Output(t, appOptions, "alb_dns_name")
	http_helper.HttpGetWithRetry(t, fmt.Sprintf("http://%s", albDnsName), nil, 200, "Hello", 30, 10*time.Second)
}
