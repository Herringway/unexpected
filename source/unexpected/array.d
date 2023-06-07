/// Random array functions
module unexpected.array;

import std.range : hasLength, hasLvalueElements, isBidirectionalRange, isRandomAccessRange;

auto removeRandom(RNG, Range)(ref RNG rng, ref Range range) @safe pure if (hasLength!Range && isBidirectionalRange!Range && hasLvalueElements!Range) {
	import std.algorithm.mutation : remove;
	import std.exception : enforce;
	import std.random : uniform;
	enforce(range.length > 0, "Error: Nothing to remove");
	auto idx = uniform(0, range.length, rng);
	auto result = range[idx];
	range = range.remove(idx);
	return result;
}

@safe unittest {
	import std.random : rndGen;
	auto array = [1];
	assert(removeRandom(rndGen, array) == 1);
	assert(array.length == 0);
}

auto randomMatchedWithoutRepeats(RNG, T)(T arr, ref RNG rng) if (hasLength!T && isRandomAccessRange!T)  {
	import std.array : array;
	import std.random : randomShuffle;
	import std.range : indexed, iota;
	auto indexes = iota(0, arr.length).array;
	randomShuffle(indexes, rng);
	return indexed(arr, indexes);
}

auto randomMatchedWithRepeats(RNG, T)(T arr, ref RNG rng) if (hasLength!T && isRandomAccessRange!T)  {
	import std.random : choice;
	import std.range;
	struct Result {
		typeof(T.init.front) front;
		bool empty() const {
			return arr.empty;
		}
		void popFront() {
			front = choice(arr, rng);
		}
	}
	Result output;
	if (!output.empty) {
		output.popFront();
	}
	return output;
}

@safe pure unittest {
	import std.random : Random;
	auto rng = Random.init;
	assert((int[]).init.randomMatchedWithRepeats(rng).empty);
	assert([1].randomMatchedWithRepeats(rng).front == 1);
}
