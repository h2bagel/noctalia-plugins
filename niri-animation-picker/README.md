# Animation Picker Plugin for Noctalia with Niri

A simple plugin that allows you to Pick a KDL animation preset and write it as an include into config.kdl or any .kdl file if included in your main config.kdl

## Features

- **Pick a KDL animation and write it into your config automatically**
- **Lists how many presets are available**
- **Chose the animations folder**
- **Chose the config file your animations will be writen to**
- **Configurable Settings**

## Installation

This plugin is part of the `noctalia-plugins` repository.

## Usage

-Set the folder in which your KDL animation presets are stored.
-Set the config file the animations will be sent to, by default config.kdl, you will need to remove your animation section from your config.kdl first.

-The plugin will write the animations as such : include "./animations/your-animation.kdl".

-All that remains is to select your animation from the plugin's panel.

## Animations
 
 You can find Animation Presets for niri alredy made here :  https://github.com/XansiVA/nirimation
