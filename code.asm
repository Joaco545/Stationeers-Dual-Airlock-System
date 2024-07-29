# Variable definitions
define int_pres 90      # Pressures in KPa
define ext_pres 0

# Pin aliases (DO NOT TOUCH, WILL BREAK)
alias ext_door d0
alias ext_vent d1
alias gas_sensor d2
alias int_door d3
alias int_vent d4
alias other d5
alias self db

# Communication Protocol Definitions
define cms_init 0       # Code initializing
define cms_cycle 1      # Airlock cycling
define cms_oti 2        # Open to Interior
define cms_ote 3        # Open to Exterior
define cms_sync 4       # Ready to Sync

# Initializes code from scratch
init:
move sp 0               # Reset stack pointer
s self Setting cms_init # Communicate init
push cms_init           # Wait until other init
jal wait_until_other_equal
jal check_state
pop r14                 # Get result
s self Setting r14      # Communicate result
yield                   # Wait until
l r1 other Setting      # other also
brle r1 cms_cycle -2    # sets its state
# If the doors are different, all ok
bne r14 r1 main
# Else gotta fight for dominance
sync:
s self Setting cms_sync # Communicate Sync
push cms_sync           # Wait until other syncs
jal wait_until_other_equal
rand r0                 # Generate random value
s other Setting r0      # Write rnd to other
yield                   # Wait until
l r1 self Setting       # mine is
breq r1 4 -2            # set by other
beq r1 r0 sync          # If equal retry
s self Setting r14      # "Remember" my state
ble r0 r1 cycle         # If less cycle
                        # If more goto main

main:
yield                   # Only run once per fram pls
l r1 other Setting      # Check if other is on init
beqz r1 init            # and follow
l r0 self Setting       # Load my state to r0
beq r0 r1 init          # If out of sync init
beq r1 cms_cycle cycle  # Cycle if other is too
l r0 ext_door Setting   # If doors dont match
l r1 ext_door Open      # desired state with actual
bne r1 r0 cycle         # state, cycle airlock
l r0 int_door Setting   # If doors dont match
l r1 int_door Open      # desired state with actual
bne r1 r0 cycle         # state, cycle airlock
j main                  # Finish loop

cycle:
l r14 self Setting      # Get current state
s self Setting cms_cycle# Set coms to cycle
add r14 r14 -2          # Make oti = 0 for select
# On register X set external if ote, internal if oti
select r13 r14 0 3      # current door (d0/d3)
select r12 r14 1 4      # current vent (d1/d4)
select r11 r14 3 0      # other door (d0/d3)
select r10 r14 4 1      # other vent (d1/d4)
select r9 r14 int_pres ext_pres #target pressure
s dr13 Open 0           # Close current door
s dr13 Setting 0        # Update door status
sleep 1                 # Wait for door to close
push 2                  # Push gas sensor device
push r12                # Push current vent
push 0                  # Push void target pressure
jal wait_until_pres_target  # Vent the airlock
push 2                  # Push gas sensor device
push r10                # Push other vent
push r9                 # Push target pressure------
s dr11 Open 1           # Open other door
s dr11 Setting 1        # Update door status 
j main
  
check_state: # returns oti | ote
l r0 ext_door Open      # If ext door closed
breq r0 0 3             # skip return
push cms_ote
j ra                    # Return
l r0 int_door Open      # If int door closed
breq r0 0 3             # skip return
push cms_oti
j ra                    # Return
min r1 int_pres ext_pres# Get min pressure
l r0 gas_sen Pressure   # Get current pressure
brlt r0 r1 3            # if pres is less min > skip
push cms_oti
j ra                    # Return
push cms_ote        # prefer vent over contamination
j ra                    # Return

wait_until_other_equal: # returns void
pop r15
yield                   # Wait until
l r1 other Setting      # other also
brne r1 r15 -2          # sets its state
j ra                    # Return

wait_until_pres_target: # Returns void
pop r0                  # Get target Pressure
pop r1                  # Get vent
pop r2                  # Get gas sensor
l r3 dr2 Pressure       # Read current pressure
beq r0 r3 ra            # Return if on target
s dr1 PressureExternal r0   # Set pressure target
brlt r3 r0 3            # Pressure < Target set Outw
s dr1 Mode 1            # else set Inward
jr 2
s dr1 Mode 0            # Set vent Outward
s dr1 On 1              # Turn on the vent
yield
l r3 dr2 Pressure       # Read current pressure
brne r3 r0 -2           # If not equal, loop back
s dr1 On 0              # If equal turn off the vent
j ra                    # Return
