#!/bin/bash
cd ../deploy-prod
/opt/terraform/terraform destroy -force -var-file=.terraform/deploy.tfvars \
                                        -target aws_route53_record.deployer-prod-active \
                                        -target aws_route53_record.deployer-prod-active-ssl \
                                        -target aws_route53_record.deployer-prod-test \
                                        -target aws_route53_record.deployer-prod-test-ssl \
                                        -target aws_elb.deployer-elb-test-ssl \
                                        -target aws_elb.deployer-elb-test \
                                        -target aws_elb.deployer-elb-active-ssl \
                                        -target aws_elb.deployer-elb-active;
/opt/terraform/terraform destroy -force -var-file=.terraform/deploy.tfvars