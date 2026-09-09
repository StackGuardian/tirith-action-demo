# tirith-action-demo

A small, real Terraform pipeline — and a demonstration of what it costs to put policy in front of it.

`main` is the pipeline on its own: GitHub Actions federates into AWS over OIDC, keeps state in S3,
plans on every pull request and applies on every push to `main`. It manages an encrypted artifact
bucket and the KMS key behind it, in `us-east-1`. Nothing here is a fixture — the credentials, the
backend, the apply and the bill are all real.

There is no Tirith on `main`. Five stacked pull requests add it, one idea each.

## The walkthrough

Read them in order — the chapter numbers below, not the PR numbers. Each PR is based on the one
before it, so every diff shows only its own change.

| | | |
|---|---|---|
| **1** | [Check the plan against policies in this repo](../../pull/16) | Three rules committed under `.tirith/policies/`, evaluated on the runner. **No StackGuardian account, no API key, no network call** — you can reproduce this one today with nothing but the files in the diff. |
| **2** | [Take the policies from the organization instead](../../pull/17) | Two lines in, three files out. The rules move to the org, and two engines appear that a runner cannot run: cost, which needs the plan priced, and rego, which needs an OPA engine. |
| **3** | [Add the analytics bucket](../../pull/18) | An ordinary-looking change that ships with its `Owner` tag left blank. The check goes red and `Apply` is skipped. Nobody had to remember to look. |
| **4** | [Give the analytics bucket an owner](../../pull/19) | One line. The gate clears. Governance is a step in the workflow, not a wall across it. |
| **5** | [Publish the terraform state after apply](../../pull/20) | A second call to the same action, this time carrying the state, so the platform holds what is actually deployed and not just what was proposed. |

Chapter 1 is the honest starting point and chapter 2 is the trade. Everything from 3 onwards works the
same either way — the rule that catches the untagged bucket in chapter 3 was a file in this repo one
chapter earlier.

## What runs

| | |
|---|---|
| AWS account | `790543352839` (sg_dash), region `us-east-1` |
| Credentials | OIDC into `arn:aws:iam::790543352839:role/tirith-action-demo-ci` — no long-lived keys |
| State | `s3://demo-tirith-action-tfstate-790543352839`, native S3 locking |
| Managed | `aws_s3_bucket.artifacts`, `aws_kms_key.artifacts` |
| Action | `StackGuardian/tirith-iac-governance-action@v2.1.1` (py-tirith 1.2.1) |

Running cost is about a dollar a month, all of it the KMS key.

## What is being checked

From chapter 2 onwards the policies live in the `wicked-hop` StackGuardian organization, not in this
repository, and are selected server-side by workflow group. Four engines report into one verdict:

- **Tirith** — every `aws_s3_bucket` must carry an `Owner` tag
- **OPA / rego** — buckets must be named `demo-*`, nothing outside `us-east-1`
  ([source](https://github.com/StackGuardian/tirith-action-demo-policies))
- **Infracost** — planned monthly cost must stay at or under 20 USD
- **Checkov** — the platform's built-in best-practice pack, advisory only

Chapter 1 runs three of these four ideas from local files: the owner-tag rule verbatim, and the two
rego rules re-expressed with native operations. The cost ceiling is the one that cannot come along —
local mode can evaluate a cost policy, but only if you hand it an `infracost breakdown` document
yourself, and nothing on a runner produces one.

Every comment reports the **planned changes** as well as the findings, so the thing a rule objected to
is visible in the change itself and not only in the verdict. Chapters 3 to 5 show it as a `diff` block —
one row per changing resource with the attributes that move underneath it — and chapter 3 is where it
pays off: the empty `Owner` sits in the plan directly above the rule that refused it.

Chapters 1 and 2 show only terraform's summary line, and that is correct rather than a gap: they change
no Terraform, so the plan is a no-op and there is nothing to draw. The summary sentence is what proves
the plan was read at all — with no plan the comment says nothing about it.

It is rendered from the masked plan on the runner, so a value terraform marked sensitive never reaches
the comment, and unchanged resources are counted rather than listed.

A rule the run cannot evaluate is reported as unevaluated rather than quietly passed — the plan and
cost rules have nothing to say about a state document, and say so instead of reporting a pass they did
not earn. Chapter 5's state call is silent for that reason: its verdict was all caveat and no news, so
it reports through neither the comment nor the check run and leaves both to the gate.

## Merging

Bottom-up — 1, then 2, 3, 4, 5. Out of order leaves chapter 3's blank tag on `main`, which blocks the
apply until chapter 4 lands. Which is, admittedly, the whole point.

Ephemeral — `terraform destroy` and delete the backend bucket and the IAM role once the demo is
retired.
