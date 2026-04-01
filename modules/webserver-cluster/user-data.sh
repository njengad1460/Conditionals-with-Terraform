#!/bin/bash
#!/bin/bash
apt-get update -y
apt-get install -y apache2
systemctl start apache2
systemctl enable apache2
echo "<h1>Hello from ASG Instance: $(hostname -f) - No down time </h1>" > /var/www/html/index.html
# Notice ${server_port} — this will come from Terraform using templatefile.
# Using a template file avoids the gotcha with inline paths.