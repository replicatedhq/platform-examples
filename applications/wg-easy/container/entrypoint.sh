#!/bin/bash

# Uncomment force_color_prompt in bashrc
sed -i 's/#force_color_prompt=yes/force_color_prompt=yes/' $HOME/.bashrc

# Source the tool completions
echo "source /tools/tool-completions.sh" >> $HOME/.bashrc

# Execute the passed command or default to bash
exec "$@"
