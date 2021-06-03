# dicey - Easy dice throwing
[![Coverage Status](https://coveralls.io/repos/Herringway/dicey/badge.svg?branch=master&service=github)](https://coveralls.io/github/Herringway/dicey?branch=master)
[![GitHub tag](https://img.shields.io/github/tag/herringway/dicey.svg)](https://github.com/Herringway/dicey)

A library for simulating various kinds of dice throws.

## Usage

### From a string

```D
auto dice = genDice("4d6");
auto result = dice.roll();
writeln(result.total); //Some number between 4 and 24
```

### Manually

```D
auto dice = Dice(1, 4, 6); //1 set of 4 d6s
auto result = dice.roll();
writeln(result.total); //Some number between 4 and 24
```

[API Documentation](http://herringway.github.io/dicey/)
