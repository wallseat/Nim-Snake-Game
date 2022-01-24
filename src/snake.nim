import std/[os, times, random, strutils]

import illwill

const
  WIDTH: int = 10
  HEIGHT: int = 10
  FRUIT_INC_SCORE: int = 15

type
  Coord = ref object of RootObj
    x, y: int

  Direction = enum
    UP,
    RIGHT,
    DOWN,
    LEFT

  Snake = ref object of RootObj
    head: Coord 
    tail: seq[Coord]
    feeded: bool
    oldDirection, curDirection: Direction
  
  Fruit = ref object of RootObj
    pos: Coord
    fruitType: FruitType
    fruitState: FruitState
  
  FruitType = enum
    SMALL,
    BIG
  
  FruitState = enum
    CREATED,
    EATEN

  Game = ref object of RootObj
    play: bool
    score: int
    speed: float
    lastUpdate: Time

proc `==`(coord_a: Coord, coord_b: Coord): bool {.inline.} =
  coord_a.x == coord_b.x and coord_a.y == coord_b.y

proc newSnake(): Snake =
  Snake(
    head: Coord(x: WIDTH div 2, y: HEIGHT div 2 - 1),
    tail: @[
      Coord(x: WIDTH div 2, y: HEIGHT div 2),
      Coord(x: WIDTH div 2, y: HEIGHT div 2 + 1)
    ],
    oldDirection: UP, 
    curDirection: UP,
    feeded: false
  )

method applyDirection(self: Snake) {.base.} =
  self.oldDirection = self.curDirection

proc newFruit(): Fruit =
  Fruit(
    pos: Coord(x: -1, y: -1),
    fruitType: SMALL,
    fruitState: EATEN
  )

proc newGame(): Game =
  Game(
    play: true,
    score: 0,
    speed: 2,
    lastUpdate: getTime()
  )

proc processKeyboardInput(snake: var Snake) =
  var key = getKey()

  case key:
    of Key.W:
      if snake.oldDirection != DOWN:
        snake.curDirection = UP
    of Key.A:
      if snake.oldDirection != RIGHT:
        snake.curDirection = LEFT
    of Key.S:
      if snake.oldDirection != UP:
        snake.curDirection = DOWN
    of Key.D:
      if snake.oldDirection != LEFT:
        snake.curDirection = RIGHT
    else: discard

proc processMove(game: var Game, snake: var Snake) =
  if game.lastUpdate.toUnixFloat + 1 / game.speed > getTime().toUnixFloat:
    return

  if snake.feeded:
    insert(snake.tail, Coord(x: snake.head.x, y: snake.head.y), 0)
    snake.feeded = false

  else:
    insert(snake.tail, pop(snake.tail), 0)
    snake.tail[0].x = snake.head.x
    snake.tail[0].y = snake.head.y

  case snake.curDirection:
    of UP:
      snake.head.y -= 1
    of RIGHT:
      snake.head.x += 1
    of DOWN:
      snake.head.y += 1
    of LEFT:
      snake.head.x -= 1
  
  snake.applyDirection()

  game.lastUpdate = getTime()
  
proc processCollide(game: var Game, snake: Snake, fruit: var Fruit) = 
  var emptyCoords = newSeq[Coord]()
  for i in 0..HEIGHT - 1:
    for j in 0..WIDTH - 1:
      let curCoord = Coord(x: i, y: j)
      if curCoord in snake.tail:
        continue
      
      emptyCoords.add(curCoord)

  if not (snake.head in emptyCoords):
    game.play = false
    
  elif snake.head == fruit.pos:
    let additionalScore = if fruit.fruitType == SMALL: FRUIT_INC_SCORE else: FRUIT_INC_SCORE + 5 + rand(20)
    game.score += additionalScore
    game.speed += additionalScore / 200
    fruit.fruitState = EATEN
    snake.feeded = true
    
proc processDraw(tb: var TerminalBuffer, game: Game, snake: Snake, fruit: Fruit) =
  for i in 0..HEIGHT - 1:
    for j in 0..WIDTH - 1:
      let curCoord = Coord(x: j, y: i)

      if snake.head == curCoord:
        tb.write(j * 2, i, fgGreen, "#")
      else:
        block elseState:
          for seg in snake.tail:
            if seg == curCoord:
              tb.write(j * 2, i, fgWhite, "#")
              break elseState
          tb.write(j * 2, i, fgBlack, "#")

  tb.write(fruit.pos.x * 2, fruit.pos.y, if fruit.fruitType == SMALL: fgRed else: fgMagenta, "#")
  tb.write(0, 10, fgWhite, "Score: ", fgYellow, align($game.score, 12, ' '))
  tb.write(0, 11, fgWhite, "Direction: ", fgYellow, align($snake.curDirection, 8, ' '))

  tb.display()

proc genFruit(snake: Snake, fruit: var Fruit) =   
  var emptyCoords = newSeq[Coord]()
  for i in 0..HEIGHT - 1:
    for j in 0..WIDTH - 1:

      let curCoord = Coord(x: i, y: j)
      if snake.head == curCoord or curCoord in snake.tail:
        continue
      
      emptyCoords.add(curCoord)

  let pickedCoord = sample(emptyCoords)
  fruit.pos = pickedCoord
  fruit.fruitType = if rand(100) >= 90: BIG else: SMALL
  fruit.fruitState = CREATED

proc processFruit(snake: Snake, fruit: var Fruit) =
  if fruit.fruitState == EATEN:
    genFruit(snake, fruit)

proc main =
  randomize()

  var tb = newTerminalBuffer(WIDTH * 2, HEIGHT + 2)
  proc exit() {.noconv.} =
    illwillDeinit()
    showCursor()
    quit(0)

  illwillInit(fullscreen=true)
  setControlCHook(exit)
  hideCursor()
 
  var game = newGame()
  var snake = newSnake()
  var fruit = newFruit()
  
  while game.play:
    processKeyboardInput(snake)
    processFruit(snake, fruit)
    processCollide(game, snake, fruit)
    processMove(game, snake)
    if game.play:
      processDraw(tb, game, snake, fruit)
  
    sleep 17

  tb.clear()
  tb.display()
  exit()

main()