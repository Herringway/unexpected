/++
+ Module for managing complex dice rolling methods.
+/
module dicey;

import std.random;
import std.range : isOutputRange;

enum Weight {
	noWeighting,
	positiveWeighting,
	negativeWeighting
}

enum Bounding {
	upper,
	upperInclusive,
	lower,
	lowerInclusive
}

struct Roll {
	bool counted;
	uint value;
	void toString(T)(T sink) const if (isOutputRange!(T, char[])) {
		import std.format : formattedWrite;
		import std.range : put;
		if (counted) {
			put(sink, "\x1B[92m");
		} else {
			put(sink, "\x1B[91m");
		}
		formattedWrite!"%s"(sink, value);
		put(sink, "\x1B[0m");
	}
}

struct DiceRollResults {
	ulong total;
	Roll[] rolls;
	void toString(T)(T sink) const if (isOutputRange!(T, char[])) {
		import std.format : formattedWrite;
		import std.range : put;
		formattedWrite!"%(%s, %): %s"(sink, rolls, total);
	}
}

struct DiceTargetResults {
	uint count;
	Roll[] rolls;
	void toString(T)(T sink) const if (isOutputRange!(T, char[])) {
		import std.format : formattedWrite;
		import std.range : put;
		formattedWrite!"%(%s, %): %s"(sink, rolls, count);
	}
}

struct Dice {
	uint sets;
	uint count;
	uint sides;
	uint numDiceQualified;
	bool takeLowestRolls;
	uint lowerRerollThreshold;
	uint upperRerollThreshold;
	int valAdd;
	Weight weighting;
	private Random rng;
	/++
	+ Roll the dice according to the set parameters.
	+/
	DiceRollResults roll() {
		DiceRollResults output;
		import std.algorithm : makeIndex, sort, sum;
		import std.range : indexed;
		uint[] rolls;
		foreach (die; 0..count) {
			auto result = rollOne();
			output.rolls ~= Roll(true, result);
			while ((result < lowerRerollThreshold) || (result > upperRerollThreshold)) {
				output.rolls[$-1].counted = false;
				result = rollOne();
				output.rolls ~= Roll(true, result);
			}
			rolls ~= result;
		}
		if (numDiceQualified < count) {
			if (takeLowestRolls) {
				rolls.sort!"a < b"();
				uint[] index = new uint[](output.rolls.length);
				makeIndex!"a.value < b.value"(output.rolls, index);
				int x = 0;
				foreach (roll; index) {
					if (output.rolls[roll].counted) {
						x++;
					}
					if (x > numDiceQualified) {
						output.rolls[roll].counted = false;
					}
				}
			} else {
				rolls.sort!"a > b"();
				uint[] index = new uint[](output.rolls.length);
				makeIndex!"a.value > b.value"(output.rolls, index);
				int x = 0;
				foreach (roll; index) {
					if (output.rolls[roll].counted) {
						x++;
					}
					if (x > numDiceQualified) {
						output.rolls[roll].counted = false;
					}
				}
			}
			rolls = rolls[0..numDiceQualified];
		}
		output.total = rolls.sum + valAdd;
		return output;
	}
	/++
	+ Roll the dice and count the number of rolls that met the specified target.
	+
	+ Params:
	+ bounding = whether the target is an upper/lower bound
	+ val = target to reach
	+/
	DiceTargetResults meetTarget(Bounding bounding = Bounding.lowerInclusive)(uint val) {
		DiceTargetResults output;
		foreach (die; 0..count) {
			auto result = rollOne();
			bool satisfied = false;

			static if (bounding == Bounding.upper) {
				satisfied = (result < val);
			} else static if (bounding == Bounding.upperInclusive) {
				satisfied = (result <= val);
			} else static if (bounding == Bounding.lower) {
				satisfied = (result > val);
			} else static if (bounding == Bounding.lowerInclusive) {
				satisfied = (result >= val);
			}

			output.rolls ~= Roll(satisfied, result);

			if (satisfied) {
				output.count++;
			}
		}
		return output;
	}
	private uint rollOne() {
		import std.algorithm.comparison : max, min;
		final switch (weighting) {
			case Weight.noWeighting:
				return uniform!"[]"(1, sides, rng);
			case Weight.negativeWeighting:
				auto x = uniform!"[]"(1, sides, rng);
				if (x > sides/2) {
					return x-uniform!"[]"(0, sides/2, rng);
				} else {
					return x;
				}
			case Weight.positiveWeighting:
				return min(sides, uniform!"[]"(1, sides, rng)+uniform!"[]"(0, sides/2, rng));
		}
	}
	this(uint seed) {
		rng = Random(seed);
	}
}

auto genDice(string str, uint seed = unpredictableSeed()) {
	import std.conv : to;
	import std.regex;
	uint sets = 1;
	uint count = 1;
	uint sides = 6;
	uint numDiceQualified = uint.max;
	bool takeLowestRolls = false;
	uint lowerRerollThreshold = 0;
	uint upperRerollThreshold = uint.max;
	int valAdd = 0;
	Weight weighting = Weight.noWeighting;
	auto setRegex = ctRegex!`(\d+)#`;
	if (auto countMatched = matchFirst(str, setRegex)) {
		sets = countMatched[1].to!uint;
		str = replaceFirst(str, setRegex, "");
	}
	auto ndqRegex = ctRegex!`(-?)(\d+)/`;
	if (auto countMatched = matchFirst(str, ndqRegex)) {
		takeLowestRolls = countMatched[1] == "-";
		numDiceQualified = countMatched[2].to!uint;
		str = replaceFirst(str, ndqRegex, "");
	}
	auto lrtRegex = ctRegex!`r(\d+)`;
	if (auto countMatched = matchFirst(str, lrtRegex)) {
		lowerRerollThreshold = countMatched[1].to!uint;
		str = replaceFirst(str, lrtRegex, "");
	}
	auto weightRegex = ctRegex!`w([+-])`;
	if (auto countMatched = matchFirst(str, weightRegex)) {
		if (countMatched[1] == "+") {
			weighting = Weight.positiveWeighting;
		} else {
			weighting = Weight.negativeWeighting;
		}
		str = replaceFirst(str, weightRegex, "");
	}
	auto cmRegex = ctRegex!`(\d+)d`;
	if (auto countMatched = matchFirst(str, cmRegex)) {
		count = countMatched[1].to!uint;
		str = replaceFirst(str, cmRegex, "");
	}
	auto vaRegex = ctRegex!`\+(\d+)`;
	if (auto countMatched = matchFirst(str, vaRegex)) {
		valAdd = countMatched[1].to!int;
		str = replaceFirst(str, vaRegex, "");
	}
	auto vanRegex = ctRegex!`-(\d+)`;
	if (auto countMatched = matchFirst(str, vanRegex)) {
		valAdd = -countMatched[1].to!int;
		str = replaceFirst(str, vanRegex, "");
	}
	auto sidesRegex = ctRegex!`d(\d+)`;
	if (auto countMatched = matchFirst(str, sidesRegex)) {
		sides = countMatched[1].to!uint;
	} else {
		sides = str.to!uint;
	}
	if (numDiceQualified > count) {
		numDiceQualified = count;
	}
	auto output = Dice(seed);
	output.sets = sets;
	output.count = count;
	output.sides = sides;
	output.numDiceQualified = numDiceQualified;
	output.takeLowestRolls = takeLowestRolls;
	output.lowerRerollThreshold = lowerRerollThreshold;
	output.upperRerollThreshold = upperRerollThreshold;
	output.valAdd = valAdd;
	output.weighting = weighting;
	return output;
}

unittest {
	import std.stdio : writeln;
	with(genDice("30d6")) {
		assert(count == 30);
		assert(sides == 6);
		assert(weighting == Weight.noWeighting);
		assert(numDiceQualified == 30);
	}
	with(genDice("30d6+5")) {
		assert(count == 30);
		assert(sides == 6);
		assert(weighting == Weight.noWeighting);
		assert(numDiceQualified == 30);
		assert(valAdd == 5);
	}
	with(genDice("20")) {
		assert(count == 1);
		assert(sides == 20);
		assert(weighting == Weight.noWeighting);
		assert(numDiceQualified == 1);
	}
	with(genDice("d20")) {
		assert(count == 1);
		assert(sides == 20);
		assert(weighting == Weight.noWeighting);
		assert(numDiceQualified == 1);
	}
	with(genDice("6#4d6")) {
		assert(sets == 6);
		assert(count == 4);
		assert(sides == 6);
		assert(weighting == Weight.noWeighting);
		assert(numDiceQualified == 4);
	}
	with(genDice("6#3/4d6")) {
		assert(sets == 6);
		assert(count == 4);
		assert(sides == 6);
		assert(weighting == Weight.noWeighting);
		assert(numDiceQualified == 3);
		assert(!takeLowestRolls);
	}
	with(genDice("-3/4d6")) {
		assert(count == 4);
		assert(sides == 6);
		assert(weighting == Weight.noWeighting);
		assert(numDiceQualified == 3);
		assert(takeLowestRolls);
	}
	with(genDice("6#4d6r1")) {
		assert(sets == 6);
		assert(count == 4);
		assert(sides == 6);
		assert(weighting == Weight.noWeighting);
		assert(numDiceQualified == 4);
		assert(lowerRerollThreshold == 1);
	}
	with(genDice("2d12+1")) {
		assert(count == 2);
		assert(sides == 12);
		assert(weighting == Weight.noWeighting);
		assert(numDiceQualified == 2);
		assert(valAdd == 1);
	}
	with(genDice("4d6w-")) {
		assert(count == 4);
		assert(sides == 6);
		assert(weighting == Weight.negativeWeighting);
		assert(numDiceQualified == 4);
	}
}