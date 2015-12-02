
function update_input()
  -- dummy: make sure all the keys are NOT pressed. (Later: handle real input
  -- and update these bits accordingly)
  memory[0xFF00] = bit32.bor(memory[0xFF00], 0x0F)
end
