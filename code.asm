# Pin aliases
alias ext_door d0
alias ext_vent d1
alias gas_sensor d2
alias int_door d3
alias int_vent d4
alias other d5
alias self db

# Communication Protcol Definitions
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
bne r0 r1 main
# Else gotta fight for dominance
sync:
s self Setting cms_sync # Communicate Sync
push cms_sync           # Wait until other syncs
jal wait_until_other_equal
rand r0                 # Generate random value
s other Setting r0      # Write rnd to other
yield                   # Wait until
l r1 self Setting       # mine is
brne r1 4 -2            # set by other
beq r1 r0 sync          # If equal retry
s self Setting r14      # "Remember" my state
ble r1 r0 cycle         # If less cycle
                        # If more goto main

main:
j main

cycle:
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
# Panic
jr 0                    # Get code stuck

wait_until_other_equal: # returns void
pop r15
yield                   # Wait until
l r1 other Setting      # other also
brne r1 r15 -2          # sets its state
j ra                    # Return
