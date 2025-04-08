## Issues
#### 1. Replicated CLI didn't report the release was not promoted to channel, instead it showed the release was created and promoted. This was confusing.

When you run `replicated release create --app $APP_NAME --yaml-dir ./release --release-notes "$RELEASE_NOTES" --promote $CHANNEL`.
Without the `--version` flag, the release will not be promoted to the channel.

But in the output of the Replicated CLI, it shows the release was created and promoted.
```
replicated release create --app dexter-test3 --yaml-dir ./release --release-notes "dddd" --promote replicated-test 

Creating release from files in ./release directory...

  • Reading manifests from ./release ✓  
  • Creating Release ✓  
    • SEQUENCE: 118
  • Promoting ✓  
    • Channel 2v70WgeXccBVgLyFzKt8qmN03Ow successfully set to release 118

Release created and promoted to channel replicated-test
```
It shows the release was created and promoted to the channel. But in fact, the release was not promoted to the channel when customer check the channel page.

Improvement:
- Add a warning when the release was not promoted to the channel without the `--version` flag.

#### 2. Replicated CLI didn't return the linting errors when using `replicated release inspect xxx`.
In the vendor portal, the release contains errors in the templates. For example,
```
wg-easy/charts/wg-easy/templates/replicated-library.yaml
Line 13 | Error: yaml: line 13: did not find expected key
Error invalid-yaml.
```

When you run `replicated release inspect xxx`, it didn't return the linting errors when the release contains errors in the templates.

But when you curl Replicated API, you can get the linting errors.
```
"lintResult": {
    "lintExpressions": [
        {
            "rule": "invalid-yaml",
            "type": "error",
            "message": "yaml: line 13: did not find expected key",
            "path": "wg-easy/charts/wg-easy/templates/replicated-library.yaml",
            "positions": [
                {
                    "start": {
                        "line": 13
                    }
                }
            ]
        }
    ],
    "isLintingComplete": false
},
```

Improvement:
- Return the linting errors when using `replicated release inspect xxx`

#### 3. Missing `Replicated app inspect` command.
In our documentation, we have `replicated app inspect` [command](https://help.replicated.com/docs/reference/cli/replicated-app-inspect/). But when we run `replicated app inspect app-name`, it returns the error:
```
Example:
  # List all applications
  replicated app ls
  
  # Create a new application
  replicated app create "My New App"
  
  # View details of a specific application
  replicated app inspect "My App Name"
  
  # Delete an application
  replicated app delete "App to Remove"
  
  # Update an application's settings
  replicated app update "My App" --channel stable
  
  # List applications with custom output format
  replicated app ls --output json

Available Commands:
  create      Create a new application
  ls          List applications
  rm          Delete an application
```
The available commands are `create`, `ls`, `rm`, and `update`. But `inspect` is not one of them.

Improvement:
- Add the `inspect` command to the `replicated app` command.


