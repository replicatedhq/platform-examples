# Advanced Options

When your customer installs your application using the KOTS Admin Console you
specify a set of config options. These options are generally a subset of the
values that your Helm chart allows to make installation easier for the
customer. There may be situations where a small number of customers need to
change values that most customers won't.  The Advanced Options pattern is
useful for these scenarios.


## Usage

1. Add a `group` to your KOTS `Config` with two fields, a checkbox to allow
   entering advanced options and a textarea for the values as a YAML file.

```yaml
- name: advanced
  title: Advanced Options
  items:
    - name: advanced_options
      help_text: |
        This option allows you to override application defaults by directly
        specifying configurations that are not exposed in this interface.
        It is for advanced users. If you're not certain, you probably do not
        need this checked.
      type: bool
      title: Specify Advanced Options
      default: false
    - name: config_values
      type: textarea
      title: Advanced Configuration Values
      help_text: |
        Specify your advanced configuration options here. These will be
        passed directly to the Helm install and upgrade commands. You must
        specify valid YAML or the install/upgrade will fail.
      when: repl{{ ConfigOptionEquals "advanced_options" "1" }}
```

2. Update the appropriate `HelmChart` option with `optionalValues` that will
   directly incorporate the YAML provided in the "Advanced Configuration
   Values" text area. Note that `nindent 8` assumes you are using two spaces
   for indentation, if not you should adjust the indentation appropriately.

```yaml
  optionalValues:  
    - when: '{{repl ConfigOptionEquals "advanced_options" "1"}}'
      recursiveMerge: true
      values: repl{{ ConfigOption "config_values" | nindent 8 }}
```

## Customization

This example assumes you have only one Helm chart that needs advanced options.
If you have more than one chart in your application and want to offer your
customer the opportunity to tailor the values for more than one chart you will
need to repeat the pattern for each chart.

## Limitations

1. There is currently no way to validate that the values of `config_values` is
   valid YAML before attempting an installation or upgrade.
