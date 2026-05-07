# engine_system
RP__II expander engine cycle development project.

## Architecture

The initial idea is that there be different individual functions for each of the subsystems, where we input the ingoing fluid's properties and get the outgoing properties according to the changes in the subsystem
After that, a function for the entire cycle, with different free-choice design parameters as inputs, would call on the individual functions one by one passing on the fluid's properties cascadingly.

Feel free to clone the repo and edit and commit whatever you guys want.
