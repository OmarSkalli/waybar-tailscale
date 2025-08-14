# waybar-tailscale

A super simple module to show and toggle the status of [Tailscale](https://tailscale.com/) on [Waybar](https://github.com/Alexays/Waybar).

### Demo

https://github.com/user-attachments/assets/be3ec235-4ef7-4951-8bbd-d1cd1c4e44e8

## Installation

For this plugin to work, you need to be able to use tailscale without using `sudo`. You can do that by executing:

```
tailscale set --operator=$USER
```

Step 1) Edit your configuration file (`~/.config/waybar/config.jsonc`).

- Add a new entry in the `modules-right` section. I placed mine after `group/tray-expander`.

```json
{
  "modules-right": [
    // ... existing code ...
    "custom/tailscale"
  ]
}
```

- Add the custom module configuration.

```json
  "custom/tailscale": {
    "exec": "~/.config/waybar/scripts/tailscale.sh --status",
    "on-click": "exec ~/.config/waybar/scripts/tailscale.sh --toggle",
    "exec-on-event": true,
    "format": "{icon} {text}",
    "format-icons": {
      "connected": "",
      "stopped": "",
      "connecting": "",
      "disconnecting": ""
    },
    "tooltip": true,
    "return-type": "json",
    "interval": 5
  },
```

Step 2) Move the `tailscale.sh` script to `~/.config/waybar/scripts/tailscale.sh`

Make the script executable:
```chmod +x ~/.config/waybar/scripts/tailscale.sh```

If you rather store the script elsewhere, make sure to edit `exec` and `on-click` to the right location from step 1.

Step 3) Edit `~/.config/waybar/style.css` to animation the connecting state. This can be added at the end of the file.

```css
.connecting {
  animation: pulse 0.8s ease-in-out infinite;
}

@keyframes pulse {
  0% {
    opacity: 1;
  }
  50% {
    opacity: 0.5;
  }
  100% {
    opacity: 1;
  }
}
```

step 4) Restart waybar for changes to take effect:

```bash
killall -SIGUSR2 waybar
```

## Acknowledgements

Thanks to [@federicovolponi](https://github.com/federicovolponi/) for the original inspiration.
Also worth checking [federicovolponi/waybar-tailscale](https://github.com/federicovolponi/waybar-tailscale/) for a different tailscale waybar UI.
