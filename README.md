# tirith-action-demo

A small, real Terraform pipeline — and a demonstration of what it costs to put policy in front of it.

`main` is the pipeline on its own: GitHub Actions federates into AWS over OIDC, keeps state in S3,
plans on every pull request and applies on every push to `main`. It manages an encrypted artifact
bucket and the KMS key behind it, in `us-east-1`.

There is no Tirith on `main`. The [`tirith` branch](../../pull/1) adds it, and the diff is the point:
seven lines, no policy files, no new job, no change to how the plan is produced.

## What runs

| | |
|---|---|
| AWS account | `790543352839` (sg_dash), region `us-east-1` |
| Credentials | OIDC into `arn:aws:iam::790543352839:role/tirith-action-demo-ci` — no long-lived keys |
| State | `s3://demo-tirith-action-tfstate-790543352839`, native S3 locking |
| Managed | `aws_s3_bucket.artifacts`, `aws_kms_key.artifacts` |

Running cost is about a dollar a month, all of it the KMS key.

## Policies

The policies live in the `wicked-hop` StackGuardian organization, not in this repository, and are
selected server-side by the workflow group. Three engines report into one verdict:

- **Tirith** — every `aws_s3_bucket` must carry an `Owner` tag
- **OPA / rego** — buckets must be named `demo-*`, nothing outside `us-east-1`
  ([source](https://github.com/StackGuardian/tirith-action-demo-policies))
- **Infracost** — planned monthly cost must stay at or under 20 USD

Ephemeral — `terraform destroy` and delete the backend bucket and the IAM role once the demo is
retired.
