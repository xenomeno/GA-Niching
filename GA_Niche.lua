dofile("Graphics.lua")
dofile("Bitmap.lua")
dofile("GA_Common.lua")

local POPULATION_SIZE       = 80
local MAX_GENERATIONS       = 120
local CROSSOVER_RATE        = 0.9
local CHROMOSOME_LENGTH     = 64
local CHROMOSOME_NORM       = math.pow(2, CHROMOSOME_LENGTH) - 1
local MUTATION_RATE         = 0.001 / CHROMOSOME_LENGTH
local GENERATION_GAP        = 0.1
local CROWDING_FACTOR       = 3
--local SHARING               = "CROWDING"
local SHARING               = "FUNCTION"
local SIGMA_SHARE           = 0.1
local PEAKS_NUMBER          = 5
local GRAPH_POINTS          = 1000
local FUNCTION_NAME         = "EqualPeaks"          -- EqualPeaks/DecreasingPeaks
local FUNCTION_NAME         = "DecreasingPeaks"     -- EqualPeaks/DecreasingPeaks

local IMAGE_WIDTH           = 1280
local IMAGE_HEIGHT          = 720
local IMAGE_NAME            = string.format("Niche/%s_%%04d.bmp", FUNCTION_NAME)
local WRITE_FRAMES          = 1

local function Min(a, b) return (not a or b < a) and b or a end
local function Max(a, b) return (not a or b > a) and b or a end

function clamp(x, a, b)
	if x < a then
		return a
	elseif x > b then
		return b
	else
		return x
	end
end

local function DecodeChromosome(chrom)
  return (chrom[2] * math.pow(2, 32) + chrom[1]) / CHROMOSOME_NORM
end

-- TODO: since x is with finite precision it Sin(x) can be precalculated
function EqualPeaks(x)
  --return 0.5 * (math.sin(-math.pi / 2 + math.pi * x * 2 * PEAKS_NUMBER) + 1.0)
  return math.pow(math.sin(5.1 * math.pi * x + 0.5), 6)
end

function DecreasingPeaks(x)
  --[[
  local scale = 100.0 - (100.0 / PEAKS_NUMBER) * math.floor(x * PEAKS_NUMBER)
  local param = -math.pi / 2 + math.pi * x * 2 * PEAKS_NUMBER
  return 0.5 * (math.sin(param) + 1.0) * scale
  --]]
  return math.exp(-4.0 * math.log(2, math.exp(1)) * math.pow(x - 0.0667, 2) / 0.64) * math.pow(math.sin(5.1 * math.pi * x + 0.5), 6)
end

local OBJECTIVE_FUNCTION    = _ENV._G[FUNCTION_NAME]

local function GenRandomChromoze(len)
  local bits = {}
  for i = 1, len do
    bits[i] = FlipCoin(0.5) and "1" or "0"
  end
  
  return table.concat(bits, "")
end

local function EvaluateChromosome(chrom)
  return OBJECTIVE_FUNCTION(chrom)
end

local function GenInitPopulation(size, chromosome_len)
  local population = { crossovers = 0, mutations = 0}
  for i = 1, size do
    local bitstring = GenRandomChromoze(chromosome_len)
    local chrom_words = PackBitstring(bitstring)
    population[i] = { chromosome = chrom_words, fitness = 0.0, objective = 0.0 }
  end
  
  return population
end

local function CalcDegradedFitness(individual, pop)
  local max, min = 1.0, 0.0001
  local sharing = 0.0
  for _, other in ipairs(pop) do
    local dist = clamp(math.abs(individual.decoded - other.decoded), 0.0, SIGMA_SHARE)
    local s = max - (max - min) * dist / SIGMA_SHARE
    sharing = sharing + s
  end
  
  return individual.objective / sharing
end

local function EvaluatePopulation(pop, old_pop, gen)
  local total_objective, min_objective, max_objective = 0.0
  for _, individual in ipairs(pop) do
    local decoded = DecodeChromosome(individual.chromosome)
    local objective = EvaluateChromosome(decoded)
    min_objective = Min(min_objective, objective)
    max_objective = Max(max_objective, objective)
    individual.decoded, individual.objective = decoded, objective
    total_objective = total_objective + objective
  end
  pop[0] = { objective = 0.0 }
  pop.total_objective = total_objective
  pop.avg_objective = total_objective / #pop
  pop.min_objective, pop.max_objective = min_objective, max_objective

  
  local total_fitness, min_fitness, max_fitness = 0.0
  for _, individual in ipairs(pop) do
    local fitness = (SHARING == "FUNCTION") and CalcDegradedFitness(individual, pop) or individual.objective
    min_fitness = Min(min_fitness, fitness)
    max_fitness = Max(max_fitness, fitness)
    individual.fitness = fitness
    individual.part_total_fitness = total_fitness
    total_fitness = total_fitness + fitness
  end  
  pop[0] = { fitness = 0.0, part_total_fitness = 0.0 }
  pop.total_fitness = total_fitness
  pop.avg_fitness = total_fitness / #pop
  pop.min_fitness, pop.max_fitness = min_fitness, max_fitness
  
  local current = pop.max_objective
  if old_pop then
    pop.interim_performance = (old_pop.interim_performance * (gen - 1) + current) / gen
    pop.ultimate_performance = Max(current, old_pop.ultimate_performance)
  else
    pop.interim_performance = current
    pop.ultimate_performance = current
  end
end

local function PlotPopulation(pop, bmp, transform)
  local points, density = {}, {}
  for idx, individual in ipairs(pop) do
    local pt = transform({x = individual.decoded, y = individual.objective})
    points[idx] = pt
    density[pt.x] = (density[pt.x] or 0) + 1
  end
  for _, pt in ipairs(points) do
    local size = 3 + math.floor(10 * (density[pt.x] / #pop))
    bmp:DrawLine(pt.x - size, pt.y - size, pt.x + size, pt.y + size, {255, 0, 255})
    bmp:DrawLine(pt.x + size, pt.y - size, pt.x - size, pt.y + size, {255, 0, 255})
    local count = tostring(density[pt.x])
    local w, h = bmp:MeasureText(count)
    bmp:DrawText(pt.x - w // 2, pt.y - h - size - 2, count, {255, 255, 255})
  end
end

local function RouletteWheelSelection(pop)
  local slot = math.random() * pop.total_fitness
  if slot <= 0 then
    return 1
  elseif slot >= pop.total_fitness then
    return #pop
  end
  
  local left, right = 1, #pop
  while left + 1 < right do
    local middle = (left + right) // 2
    local part_total = pop[middle].part_total_fitness
    if slot == part_total then
      return middle
    elseif slot < part_total then
      right = middle
    else
      left = middle
    end
  end
  
  return (slot < pop[left].part_total_fitness + pop[left].fitness) and left or right
end

local function Crossover(mate1, mate2)
  local offspring1 = { chromosome = CopyBitstring(mate1.chromosome) }
  local offspring2 = { chromosome = CopyBitstring(mate2.chromosome) }
  local crossovers = 0
  
  if FlipCoin(CROSSOVER_RATE) then
    local xsite = math.random(1, CHROMOSOME_LENGTH)
    ExchangeTailBits(offspring1.chromosome, offspring2.chromosome, xsite)
    crossovers = 1
  end
  
  return offspring1, offspring2, crossovers
end

local function Mutate(offspring)
  local mutations = 0
  
  local chromosome = offspring.chromosome
  local word_idx, bit_pos, power2 = 1, 1, 1
  for bit = 1, chromosome.bits do
    if FlipCoin(MUTATION_RATE) then
      local word = chromosome[word_idx]
      local allele = word & power2
      chromosome[word_idx] = (allele ~= 0) and (word - power2) or (word + power2)
      mutations = mutations + 1
    end
    bit_pos = bit_pos + 1
    power2 = power2 * 2
    if bit_pos > GetBitstringWordSize() then
      word_idx = word_idx + 1
      bit_pos, power2 = 1, 1
    end
  end
  
  return mutations
end

local function ChooseReplacement(pop, offspring)
  local subpop, choosen = {}, {[0] = true}
  while #subpop < CROWDING_FACTOR do
    local idx = math.random(1, #pop)
    while choosen[idx] do
      idx = math.random(1, #pop)
    end
    table.insert(subpop, idx)
  end
  
  local most_similar_idx, most_similar_bits
  for _, idx in ipairs(subpop) do
    local individual = pop[idx]
    local bits = GetCommonBits(individual.chromosome, offspring.chromosome)
    if not most_similar_idx or most_similar_bits < bits then
      most_similar_idx = idx
      most_similar_bits = bits
    end
  end
  
  return most_similar_idx
end

local function DrawFunction(bmp, func, name)
  local func_points = { color = {0, 255, 0} }
  local graph = { funcs = { [name] = func_points } }
  for i = 0, GRAPH_POINTS - 1 do
    local x = i / (GRAPH_POINTS - 1)
    local y = func(x)
    func_points[i + 1] = {x = x, y = y}
  end
  
  return DrawGraphs(bmp, graph, nil, nil, nil, nil, "skip KP")
end

local function RunNicheGA()
  local start_clock = os.clock()
  
  local bmp = Bitmap.new(IMAGE_WIDTH, IMAGE_HEIGHT, {0, 0, 0})
  local transform = DrawFunction(bmp, OBJECTIVE_FUNCTION, FUNCTION_NAME)
  
  local pop = GenInitPopulation(POPULATION_SIZE, CHROMOSOME_LENGTH)
  EvaluatePopulation(pop)
  if WRITE_FRAMES then
    local img = bmp:Clone()
    PlotPopulation(pop, img, transform)
    local filename = string.format(IMAGE_NAME, 1)
    print(string.format("Writing '%s' ...", filename))
    img:WriteBMP(filename)
  end
  
  local overlap_count = (SHARING == "CROWDING") and math.ceil(GENERATION_GAP * #pop) or #pop
  for gen = 2, MAX_GENERATIONS do
    local new_pop = {crossovers = pop.crossovers, mutations = pop.mutations}
    while #new_pop < overlap_count do
      local idx1 = RouletteWheelSelection(pop)
      local idx2 = RouletteWheelSelection(pop)
      local offspring1, offspring2, crossover = Crossover(pop[idx1], pop[idx2])
      new_pop.crossovers = new_pop.crossovers + crossover
      local mutations1 = Mutate(offspring1)
      table.insert(new_pop, offspring1)
      new_pop.mutations = new_pop.mutations + mutations1
      if #new_pop < overlap_count then         -- shield the case of odd size popuations
        local mutations2 = Mutate(offspring2)
        table.insert(new_pop, offspring2)
        new_pop.mutations = new_pop.mutations + mutations2
      end
    end
    if SHARING then
      if SHARING == "CROWDING" then
        EvaluatePopulation(new_pop)
        for _, individual in ipairs(new_pop) do
          local idx = ChooseReplacement(pop, individual)
          if pop[idx].fitness < individual.fitness then
            pop[idx] = individual
          end
        end
        pop.crossovers, pop.mutations = new_pop.crossovers, new_pop.mutations
        EvaluatePopulation(pop, pop, gen)
      else
        EvaluatePopulation(new_pop, pop, gen)
        pop = new_pop
      end
    else
      EvaluatePopulation(new_pop, pop, gen)
      pop = new_pop
    end
    if WRITE_FRAMES and gen % WRITE_FRAMES == 0 then
      local img = bmp:Clone()
      PlotPopulation(pop, img, transform)
      local filename = string.format(IMAGE_NAME, (WRITE_FRAMES == 1) and gen or (1 + gen // WRITE_FRAMES))
      print(string.format("Writing '%s' ...", filename))
      img:WriteBMP(filename)
    end
  end
  
  local time = os.clock() - start_clock
  local time_text = string.format("Time (Lua 5.3): %ss", time)
  print(time_text)
end

RunNicheGA()
