module rando.common;

import rando.names;
import rando.palette;

import std.typecons;

struct Options {
	ColourRandomizationLevel colourRandomizationStyle = ColourRandomizationLevel.shiftHue;
	Nullable!uint seed;
}

void randomize(Game)(ref Game game, const uint seed, const Options options) {
	import std.random : Random, uniform;
	import std.stdio : writeln;
	import std.traits : getSymbolsByUDA, getUDAs, hasUDA;

	auto rand = Random(seed);
	uint nextSeed = seed;

	static foreach (field; getSymbolsByUDA!(Game, Name)) {{
		enum ctOptions = getUDAs!(field, Name)[0];
		static if (hasUDA!(field, Label)) {
			enum label = getUDAs!(field, Label)[0];
			writeln("\t- "~label.name~"...");
		}
		debug(verbose) writeln("Randomizing "~field.stringof~"...");
		foreach (ref name; mixin("game."~field.stringof)[]) {
			randomizeNames!ctOptions(name, rand, nextSeed, options);
		}
		nextSeed = rand.uniform!uint;
	}}
	static foreach (field; getSymbolsByUDA!(Game, Palette)) {{
		enum ctOptions = getUDAs!(field, Palette)[0];
		static if (hasUDA!(field, Label)) {
			enum label = getUDAs!(field, Label)[0];
			writeln("\t- "~label.name~"...");
		}
		debug(verbose) writeln("Randomizing "~field.stringof~"...");
		foreach (ref name; mixin("game."~field.stringof)[]) {
			randomizePalette!ctOptions(name, rand, nextSeed, options);
		}
		nextSeed = rand.uniform!uint;
	}}
}
