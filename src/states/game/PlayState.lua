PlayState = Class{__includes = BaseState}

function PlayState:init(numPlayers)
    print("Number of players: " .. tostring(numPlayers))
    self.level = generateLevel(2)

    self.playerTriangle = Triangle(gFonts['medium']:getWidth('Player 1   '), 0, 25, gFonts['medium']:getHeight() - 10)

    gPoints = self.level.points

    local nodeNumbers = {}
    for i = 1, #gPoints do
        table.insert(nodeNumbers, i)
    end

    shiftX = gFonts['medium']:getWidth('Player 1')
    scale = (VIRTUAL_WIDTH - shiftX) / VIRTUAL_WIDTH
    shiftY = VIRTUAL_HEIGHT - VIRTUAL_HEIGHT * scale
    translatePoints(gPoints, shiftX, shiftY, scale)

    self.numPlayers = numPlayers
    self.players = {}
    for i = 1, self.numPlayers do
        table.insert(self.players, Player(0, {}))
    end
    self.currentPlayer = 1

    self.gameArea = shoelace(points_set(self.level.figure_path))
    print("Total area of game: ", self.gameArea)
    -- self.gameArea = 0

    self.cycles = {}
    self.graph = Graph(nodeNumbers)
    self.graph.points = gPoints

    for i = 1, #self.graph.points, 2 do
        self.graph:add_edge(i, i + 1)
        -- table.insert(self.lines, {i, i + 1})
    end

    self.selected = nil
    self.ver = false
end

function PlayState:checkGameOver()
    totalArea = 0
    for i, c in pairs(self.cycles) do
        totalArea = totalArea + shoelace(points_set(c))
    end
    return totalArea == self.gameArea
end

function line_distance(a, b)
    return point_length(a[1], a[2], b[1], b[2])
end

function lies_between(a, c, b)
    if math.abs(line_distance(a, b) + line_distance(b, c) - line_distance(a, c)) < POINT_IN_LINE_SEGMENT_TOLERANCE_VALUE then
        return true
    end
    return false
end

function PlayState:validLine(line1)
    a = gPoints[line1[1]]
    c = gPoints[line1[2]]

    local midpoint = {(a[1] + c[1])/2, (a[2] + c[2])/2}

    for i,c in pairs(self.cycles) do
        v = getVertices(c)
        if pointInPolygon(midpoint, v) then
            return false
        end
    end

    for i, line2 in pairs(self.graph.edges) do
        -- check if the line already exists
        if (line1[1] == line2[1] and line1[2] == line2[2]) or (line1[2] == line2[1] and line1[1] == line2[2]) then
            return false
        end
        coordinateLine1 = deepcopy({self.graph.points[line1[1]], self.graph.points[line1[2]]})
        coordinateLine2 = deepcopy({self.graph.points[line2[1]], self.graph.points[line2[2]]})

        if lines_intersect(coordinateLine1, coordinateLine2) then
            return false
        end
    end

    for i, b in pairs(gPoints) do
        if table.contains(line1, i) then
            goto continue
        end

        if lies_between(a, c, b) then
            return false
        end

        ::continue::
    end

    -- check whether the line is trying to connect two cycles together
    -- for i, cycle in pairs(self.cycles) do
    --     if table.contains(cycle, line1[1]) and table.contains(cycle, line1[2]) then
    --         return false
    --     end
    -- end

    return true
end

function validateCycle(cycle)
    cyc_copy = deepcopy(cycle)
    table.insert(cyc_copy, cyc_copy[1])
    table.insert(cyc_copy, cyc_copy[2])

    remove = {}
    for i = 1, #cyc_copy - 2 do
        a = gPoints[cyc_copy[i]]
        b = gPoints[cyc_copy[i + 1]]
        c = gPoints[cyc_copy[i + 2]]
        if lies_between(a, c, b) then
            remove[cyc_copy[i + 1]] = true
        end
    end

    new_cyc = {}
    for i = 1, #cyc_copy - 2 do
        if not remove[cyc_copy[i]] then
            table.insert(new_cyc, cyc_copy[i])
        end
    end

    return new_cyc
end

function PlayState:update(dt)
    mouseX, mouseY = push:toGame(love.mouse.getX(), love.mouse.getY())
    if love.mouse.keysPressed[1] and not self.gameover then
        if self.selected then
            local other = nil
            for i, point in pairs(self.graph.points) do
                if point_length(mouseX, mouseY, point[1], point[2]) <= POINT_HITBOX then
                    other = i
                end
            end
            if other and self.selected ~= other then
                -- at this point
                if self:validLine({self.selected, other}) then
                    self.graph:add_edge(self.selected, other)

                    local nextCycles = minimum_cycle_basis(self.graph)

                    for i, c in pairs(nextCycles) do
                        nextCycles[i] = validateCycle(c)
                    end

                    local newCycles = getNewCycles(nextCycles, self.cycles)

                    for i, c in pairs(newCycles) do
                        table.insert(self.cycles, c)
                    end

                    self.players[self.currentPlayer]:update(newCycles)
                    self.currentPlayer = math.max((self.currentPlayer + 1)%(self.numPlayers + 1), 1)
                    local h = (self.currentPlayer - 1) * gFonts['medium']:getHeight() + (2 * (self.currentPlayer - 1)) * gFonts['small']:getHeight()
                    Timer.tween(1, {
                        [self.playerTriangle] = {y = h}
                    })
                    self.gameOver = self:checkGameOver()
                    if self.gameOver then
                        bestPlayer = nil
                        bestScore = 0

                        bestArea = 0
                        bestPlayersArea = {}

                        for i, player in pairs(self.players) do
                            if not bestPlayer or player.points > bestScore then
                                bestPlayer = i
                                bestScore = player.points
                            end

                            if player.pentagonArea > bestArea then
                                bestArea = player.pentagonArea
                                bestPlayersArea = {i, }
                            elseif player.pentagonArea == bestArea then
                                table.insert(bestPlayersArea, i)
                            end
                        end

                        local points = #bestPlayersArea == 1 and 3 or 2
                        for i, player in pairs(bestPlayersArea) do
                            self.players[player].points = self.players[player].points + points
                        end

                        gStateStack:push(GameOverState(bestPlayer, bestPlayersArea, self.players))
                    end
                else
                    gSounds['deny-connection']:play()
                    -- graphics to show line and then fade it out
                end
            end
            self.selected = nil
        else
            for i, point in pairs(self.graph.points) do
                if point_length(mouseX, mouseY, point[1], point[2]) <= POINT_HITBOX then
                    self.selected = i
                end
            end
        end
    end
end

function PlayState:render()
    if not self.gameover then
        love.graphics.clear(255, 255, 255, 255)
        self.playerTriangle:render()

        for i, cycle in pairs(self.cycles) do
            if #cycle == 5 then
                love.graphics.setColor(255, 0, 0, 200)
            else
                love.graphics.setColor(194, 197, 204, 200)
            end
            local vertices = getVertices(cycle)
            if convex then
                love.graphics.polygon('fill', vertices)
            else
                triangles = love.math.triangulate(vertices)
                for i, polygon_triangle in pairs(triangles) do
                    love.graphics.polygon('fill', polygon_triangle)
                end
            end
        end

        love.graphics.setColor(0, 0, 0)

        shiftX = 100
        shiftY = gFonts['medium']:getHeight()

        for i, line in pairs(self.graph.edges) do
            love.graphics.line(self.graph.points[line[1]][1], self.graph.points[line[1]][2], self.graph.points[line[2]][1], self.graph.points[line[2]][2])
        end

        for i, point in pairs(self.graph.points) do
            if self.selected == i then
                love.graphics.setColor(255, 0, 0)
            else
                love.graphics.setColor(0, 0, 0)
            end
            love.graphics.setFont(gFonts['small'])
            love.graphics.print(tostring(i), point[1], point[2])
            love.graphics.circle('fill', point[1], point[2], 5)
        end

        love.graphics.setColor(0, 0, 0)
        love.graphics.setFont(gFonts['medium-bigger'])
        if self.gameOver then
            love.graphics.printf("Game over.", 0, 0, VIRTUAL_WIDTH, 'center')
        else
            love.graphics.printf("Player " .. tostring(self.currentPlayer) .. "'s turn!", 0, 0, VIRTUAL_WIDTH, 'center')
        end
        for i = 1, self.numPlayers do
            local h = (i - 1) * gFonts['medium']:getHeight() + (2 * (i - 1)) * gFonts['small']:getHeight()
            love.graphics.setFont(gFonts['medium'])
            love.graphics.printf("Player " .. tostring(i), 0, h, VIRTUAL_WIDTH)

            love.graphics.setFont(gFonts['small'])
            love.graphics.printf("Points: " .. tostring(self.players[i].points), 0, h + gFonts['medium']:getHeight(), VIRTUAL_WIDTH)
            love.graphics.printf("Area: " .. tostring(math.floor(self.players[i].pentagonArea, 0)), 0, h + gFonts['medium']:getHeight() + gFonts['small']:getHeight(), VIRTUAL_WIDTH)
        end
    end
end
