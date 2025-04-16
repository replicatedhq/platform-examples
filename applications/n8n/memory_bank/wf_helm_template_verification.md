# Workflow: Helm Template Verification

## Current tasks from user prompt
- Add a new task to run helm template to verify current values

## Plan (simple)
- Add a new recipe to the justfile that executes `helm template` command
- The command should use the n8n chart directory and the values file
- The output should be displayed or redirected to a file for review
- This will allow verification of the rendered Kubernetes manifests before actually deploying

## Steps
1. Examine the current justfile structure
2. Add a new recipe called `helm-template` or similar
3. Implement the command to run helm template with appropriate parameters
4. Test the command to ensure it works properly

## Things done
- Added a new `helm-template` recipe to the justfile that executes `helm template n8n ./charts/n8n -f ./charts/n8n-values.yaml --debug`
- The command will render all templates with the current values file without actually installing anything
- Added the `--debug` flag to provide more detailed output for better verification

## TODOs
- Test the command by running `just helm-template`
- Consider adding an option to save output to a file for review 