# plan = Forklift::Plan.new

# Or, you can pass configs
plan = Forklift::Plan.new({
  # logger: {debug: true}
})

plan.do! do
  # Your plan here.
end
