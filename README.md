# orb_delay

Its a delay which circles through your head.
Since it works with higher order ambisonics (HOA) headphone use is recommended.

It runs on a supercollider server and thus can be used for the SPRAWL - System (https://hvc.berlin/projects/sprawl_system/).   
There is an additionally pure data patch to controll the delay parameters with OSC messages. 

In the "local" folder is a version of the server with some testing sounds and parameter settings.

## requirements

- supercollider with SC-HOA library installed
- PureData

## fist steps

Execute the server file with `sclang simple_SERVER_orb_sprawl_final.scd`.   
Start `delay_sprawl.pd` on your local machine and click in the opened window on `connect...`. Insert the respective destination address.
The port will always be 57120. (Supercollider listening port)


## local use

For local use you need to open the file `simple_SERVER_orb_local` in supercollider and set all the settings for the server (first few lines), before booting it.
Maybe you need to specify your devices.   
Then boot and play some Synths.   
Set delay parameters inline or with the pd patch connected to localhost.

