# tirith-action-demo

A small, real Terraform pipeline — and a demonstration of what it costs to put policy in front of it.

`main` is the pipeline on its own: GitHub Actions federates into AWS over OIDC, keeps state in S3,
plans on every pull request and applies on every push to `main`. It manages an encrypted artifact
bucket and the KMS key behind it, in `us-east-1`. Nothing here is a fixture — the credentials, the
backend, the apply and the bill are all real.

There is no Tirith on `main`. Four stacked pull requests add it, one idea each.

## The walkthrough

Read them in order. Each is based on the one before it, so each diff shows only its own change.

| | | |
|---|---|---|
| **1** | [Route the plan through IaC governance](../../pull/1) | Eight lines in the workflow. No policy files, no new job, no change to how the plan is produced — and the check comes back with four engines reporting on infrastructure that was already deployed. |
| **2** | [Add the analytics bucket](../../pull/2) | An ordinary-looking change that ships with its `Owner` tag left blank. The check goes red and `Apply` is skipped. Nobody had to remember to look. |
| **3** | [Fill in the owner tag](../../pull/3) | One line. The gate clears. Governance is a step in the workflow, not a wall across it. |
| **4** | [Publish the state after apply](../../pull/4) | A second call to the same action, this time carrying the terraform state, so the platform holds what is actually deployed and not just what was proposed. |

## What runs

| | |
|---|---|
| AWS account | `790543352839` (sg_dash), region `us-east-1` |
| Credentials | OIDC into `arn:aws:iam::790543352839:role/tirith-action-demo-ci` — no long-lived keys |
| State | `s3://demo-tirith-action-tfstate-790543352839`, native S3 locking |
| Managed | `aws_s3_bucket.artifacts`, `aws_kms_key.artifacts` |

Running cost is about a dollar a month, all of it the KMS key.

## What is being checked

The policies live in the `wicked-hop` StackGuardian organization, not in this repository, and are
selected server-side by workflow group. Four engines report into one verdict:

- **Tirith** — every `aws_s3_bucket` must carry an `Owner` tag
- **OPA / rego** — buckets must be named `demo-*`, nothing outside `us-east-1`
  ([source](https://github.com/StackGuardian/tirith-action-demo-policies))
- **Infracost** — planned monthly cost must stay at or under 20 USD
- **Checkov** — the platform's built-in best-practice pack, advisory only

A rule the run cannot evaluate is reported as unevaluated rather than quietly passed — the plan and
cost rules have nothing to say about a state document, and say so instead of reporting a pass they did
not earn. PR 4's state call is silent for that reason: its verdict was all caveat and no news, so it
reports through neither the comment nor the check run and leaves both to the gate.

## Merging

Bottom-up — 1, then 2, 3, 4. Out of order leaves PR 2's blank tag on `main`, which blocks the apply
until PR 3 lands. Which is, admittedly, the whole point.

Ephemeral — `terraform destroy` and delete the backend bucket and the IAM role once the demo is
retired.
