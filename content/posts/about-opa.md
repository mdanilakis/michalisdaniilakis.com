---
title: "About OPA"
date: 2022-05-28
tags:
- opa
- open policy agent
- security
- access control
---

OPA is an expression that is often associated with celebrations and plate smashing in Greek culture,
but this post is not about that.
<!--more-->

<p></p>
{{< image classes="nocaption fig-50 clear" src="/images/content/opa-horizontal-black.png" title="Open Policy Agent" >}}

Open Policy Agent (OPA) has been gaining popularity over the last few years
as more and more [companies adopt OPA](https://github.com/open-policy-agent/opa/blob/main/ADOPTERS.md) to secure
their workflows. Using policies as code that are decoupled from implementation, unified fine-grained control
can be deployed across distributed systems independently of other responsibilities of an application.


> You can think of it as a concierge for your service who can answer detailed questions on behalf of your users to meet their specific needs.

OPA can be deployed as a daemon or library across API gateways and cloud-native stacks, and can act as a
decision-making component responsible for controlling access to resources. These decisions are based
on policies and contextual data that are loaded from databases or user management systems.

<p></p>
{{< image classes="nocaption fancybox" src="/images/content/opa-http-high-level.jpeg" title="OPA HTTP Architecture" >}}

Policies are a set of rules that an organization chooses to apply and can be expressed using a declarative
language called Rego. During a policy evaluation request attributes, JWT tokens, and data from external sources
can be used to make a decision. The result can be sent to the upstream client, along with additional data
to accept or deny a request.

```text
package application.authz

# Only owner can update the pet's information
# Ownership information is provided as part of OPA's input
default allow = false

allow {
    input.method == "PUT"
    some petid
    input.path = ["pets", petid]
    input.user == input.owner
}
```

A policy evaluation with the following input would result with `allow: false` as the requester user
is not the owner of the resource.

```json
{
    "method": "PUT",
    "owner": "bob@hooli.com",
    "path": [
        "pets",
        "pet113-987"
    ],
    "user": "alice@hooli.com"
}
```

OPA has [builtin support for JSON Web Tokens](https://www.openpolicyagent.org/docs/latest/faq/#json-web-tokens-jwts)
(JWTs) to verify and extract information you need to make a policy decision. If your authentication is set up
so that when a user logs in you create a JWT with that user's attributes (or any other data as far as OPA is concerned).
Then you hand that JWT to OPA and use OPA’s specialized support for JWTs to extract the information you need
to make a policy decision.

In summary, OPA can help deploy unified access control across your stack that is decoupled from applications,
but that is easier said than done. Operationally speaking this involves setting up sidecars, libraries, and
configuration in your cloud stack. Policies should be maintained in a data store that needs to be accessible
from the OPA processes; so you may have to consider a CI/CD pipeline to make sure your policies are tested and
deployed on merge to trunk.

[Open Policy Agent Documentation](https://www.openpolicyagent.org/docs/latest/)

eof.
