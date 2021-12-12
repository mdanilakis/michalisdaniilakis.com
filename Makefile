SHELL := /bin/bash
AWS := aws
HUGO := hugo
PUBLIC_FOLDER := public/
S3_BUCKET = s3://michalisdaniilakis.com/
CLOUDFRONT_ID := E9F2PKJ3VUGCI
DOMAIN = michalisdaniilakis.com
SITEMAP_URL = https://michalisdaniilakis.com/sitemap.xml

DEPLOY_LOG := deploy.log

.EXPORT_ALL_VARIABLES:

AWS_PROFILE = mdanilakis@gmail.com

.ONESHELL:

build-production:
	HUGO_ENV=production $(HUGO)

deploy: build-production
	echo "Copying files to server..."
	$(AWS) s3 sync $(PUBLIC_FOLDER) $(S3_BUCKET) --size-only --delete | tee -a $(DEPLOY_LOG)
	# filter files to invalidate cdn
	grep "upload\|delete" $(DEPLOY_LOG) | sed -e "s|.*upload.*to $(S3_BUCKET)|/|" | sed -e "s|.*delete: $(S3_BUCKET)|/|" | sed -e 's/index.html//' | sed -e 's/\(.*\).html/\1/' | tr '\n' ' ' | xargs aws cloudfront create-invalidation --distribution-id $(CLOUDFRONT_ID) --paths
	curl --silent "http://www.google.com/ping?sitemap=$(SITEMAP_URL)"
	curl --silent "http://www.bing.com/webmaster/ping.aspx?siteMap=$(SITEMAP_URL)"

aws-cloudfront-invalidate-all:
	$(AWS) cloudfront create-invalidation --distribution-id $(CLOUDFRONT_ID) --paths "/*"