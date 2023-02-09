# Sync Platform For Agency

Github Action for triggering the platform sync workflow in FE Platform repository for a given brand.


## Arguments

| Argument Name            | Required   | Default     | Description           |
| ---------------------    | ---------- | ----------- | --------------------- |
| `repo_token`           | True       | N/A         | Github access token of the platform repository owner. |
| `client_payload`         | True       | N/A         | Payload containing brandname to be passed in JSON format. |


## Example Usage

```yaml
- uses: AEMCS/platform-sync@v.0.1
  with:
    repo_token: ${{ secrets.GITHUB_PERSONAL_ACCESS_TOKEN }}
    client_payload: '{brandName: <agency_brand_name>}'
```

