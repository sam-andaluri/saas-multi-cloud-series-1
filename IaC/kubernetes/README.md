## Infrastructure as Code

This folder will contain terraform scripts to create resources needed for this series. For Kubernetes, the supplied code only provides cluster creation. I did not supply ingress resources, for the reason that there are many ingress controllers to choose from. See the next section on my notes.

## Ingress controllers

[AWS ALB](https://docs.aws.amazon.com/eks/latest/userguide/alb-ingress.html) ingress is going thru an evolution of its own. Terminating [SSL using ACM with the ingress](https://aws.amazon.com/premiumsupport/knowledge-center/terminate-https-traffic-eks-acm/).

[Ambassador](https://www.getambassador.io/) is one of the easiest ingress controllers to install. They offer a simple configuration generator [1] to similar to Spring initializer to add various features you need and the site generates ready to use commands with configuration. You can save multiple configurations using github auth.

[NGINX](https://kubernetes.github.io/ingress-nginx/deploy/#network-load-balancer-nlb) is another popular ingress controller that uses AWS Network Load Balancer based ingress controller. For using NGINX with AWS, see [this](https://aws.amazon.com/premiumsupport/knowledge-center/eks-access-kubernetes-services/)

[Contour](https://aws.amazon.com/blogs/containers/securing-eks-ingress-contour-lets-encrypt-gitops/) ingress controller.

## Containers

## Useful links

1. https://app.getambassador.io/initializer/
2. https://kubernetes.io/docs/reference/kubectl/cheatsheet/
3. https://eksctl.io/introduction/
4. https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_cluster
5. https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_node_group
6. https://medium.com/risertech/production-eks-with-terraform-5ad9e76db425
7. https://aws.amazon.com/blogs/opensource/network-load-balancer-nginx-ingress-controller-eks/
