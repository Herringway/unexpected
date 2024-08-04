/// Functions for "luck", or influenced results
module unexpected.influence;

import std.range : ElementType, isInfinite;

enum hasMinMax(T) = is(typeof(T.min) == typeof(T.max)) && is(typeof(T.min) == T);

auto influencedChoice(Range, Rand, Element = ElementType!Range)(double luck, ref Rand rng, Range range) if (hasMinMax!(ElementType!Range)) {
	return influencedChoiceCommon!true(luck, rng, range, ElementType!Range.min, ElementType!Range.max);
}
auto influencedChoice(Range, Rand, Element = ElementType!Range)(double luck, ref Rand rng, Range range, Element worst, Element best) {
	return influencedChoiceCommon!true(luck, rng, range, worst, best);
}
auto influencedChoice(Range, Rand, Element = ElementType!Range)(double luck, ref Rand rng, Range range) if (!isInfinite!Range && !hasMinMax!(ElementType!Range)) {
	return influencedChoiceCommon!false(luck, rng, range, Element.init, Element.init);
}
auto influencedChoiceCommon(bool useWorstBest = true, Range, Rand, Element = ElementType!Range)(double luck, ref Rand rng, Range range, Element worst, Element best)
	in(!range.empty, "Nothing to choose")
	in(!useWorstBest || (best >= worst), "Worst value must be less than best")
	out(result; !useWorstBest || (result >= worst), "Result is less than worst value")
	out(result; !useWorstBest || (result <= best), "Result is greater than best value")
{
	import std.algorithm.comparison : min;
	import std.math : isInfinity;
	import std.random : uniform01;
	static if (useWorstBest) {
		if (luck.isInfinity) {
			if (luck > 0) {
				return best;
			} else {
				return worst;
			}
		}
	}
	auto chosen = range.front;
	range.popFront();
	bool negative = luck < 0.0;
	if (luck < 0.0) {
		luck = -luck;
	}
	while ((luck > 0.0) && !range.empty) {
		static if (useWorstBest) {
			if (chosen > best) {
				return best;
			} else if (chosen < worst) {
				return worst;
			}
		}
		const remaining = min(luck, 1.0);
		luck -= remaining;
		if (remaining >= uniform01(rng)) {
			auto next = range.front;
			range.popFront();
			if (negative ^ (next > chosen)) {
				chosen = next;
			}
		}
	}
	return chosen;
}

@safe pure unittest {
	import std.random : Random, uniform;
	import std.range : generate;
	static struct Result {
		enum min = Result(0);
		enum max = Result(100);
		int x;
		int opCmp(Result b) const pure @safe {
			return x - b.x;
		}
	}
	Random rand;
	enum iterations = 100;
	double test(double luck) {
		long total;
		foreach (i; 0 .. iterations) {
			total += influencedChoice(luck, rand, generate!(() => Result(uniform(0, 100, rand)))).x;
		}
		return total / double(iterations);
	}
	assert(test(0.0) < test(1.0));
	assert(test(0.0) > test(-1.0));
	assert(test(double.infinity) == 100);
	assert(test(-double.infinity) == 0);

	double test2(double luck, int min = int.min, int max = int.max) {
		long total;
		foreach (i; 0 .. iterations) {
			const value = influencedChoice(luck, rand, generate!(() => uniform(0, 100, rand)), min, max);
			assert(value >= min);
			assert(value <= max);
			total += value;
		}
		return total / double(iterations);
	}
	assert(test2(0.0) < test2(1.0));
	assert(test2(0.0) > test2(-1.0));
	assert(test2(double.infinity) == int.max);
	assert(test2(-double.infinity) == int.min);
	assert(test2(double.infinity, 0, 100) == 100);
	assert(test2(-double.infinity, 0, 100) == 0);
	assert(test2(0.0, 0, 100) > test2(-1.0, 0, 100));
}

@safe pure unittest {
	import std.random : Random, uniform;
	import std.range : generate, take;
	static struct Result {
		int x;
		int opCmp(Result b) const pure @safe {
			return x - b.x;
		}
	}
	Random rand;
	enum iterations = 100;
	double test(double luck, int min = int.min, int max = int.max) {
		long total;
		foreach (i; 0 .. iterations) {
			const value = influencedChoice(luck, rand, generate!(() => Result(uniform(0, 100, rand))).take(100));
			assert(value.x >= min);
			assert(value.x <= max);
			total += value.x;
		}
		return total / double(iterations);
	}
	assert(test(0.0) < test(1.0));
	assert(test(0.0) > test(-1.0));
	assert(test(double.infinity) > test(-double.infinity));
	assert(test(double.infinity, 0, 100) > test(-double.infinity, 0, 100));
	assert(test(0.0, 0, 100) > test(-1.0, 0, 100));
}

auto influencedWeightedChoice(Range, Weights, Rand, Element = ElementType!Range)(double luck, ref Rand rng, Range range, Weights weights) if (hasMinMax!(ElementType!Range)) {
	return influencedWeightedChoice(luck, rng, range, weights, Element.min, Element.max);
}
auto influencedWeightedChoice(Range, Weights, Rand, Element = ElementType!Range)(double luck, ref Rand rng, Range range, Weights weights, Element worst, Element best) {
	import std.random : dice;
	import std.range : drop, front, generate;
	return influencedChoiceCommon!true(luck, rng, generate!({ return range.drop(dice(rng, weights)).front; }), worst, best);
}

@safe pure unittest {
	import std.random : Random;
	import std.range : iota;
	Random rand;
	enum iterations = 100;
	enum vals = [100, 50, 33, 0, 25];
	double test2(double luck, int min, int max) {
		long total;
		foreach (i; 0 .. iterations) {
			const value = influencedWeightedChoice(luck, rand, vals, iota(5), min, max);
			assert(value >= min);
			assert(value <= max);
			total += value;
		}
		return total / double(iterations);
	}
	assert(test2(0.0, 0, 100) < test2(1.0, 0, 100));
	assert(test2(0.0, 0, 100) > test2(-1.0, 0, 100));
	assert(test2(double.infinity, 0, 100) == 100);
	assert(test2(-double.infinity, 0, 100) == 0);
	assert(test2(0.0, 0, 100) > test2(-1.0, 0, 100));
}

auto influencedUniform(Rand, T)(double luck, ref Rand rng, T worst, T best) {
	import std.random : uniform;
	static auto uniformRange(Rand rng, T worst, T best) {
		struct Result {
			T front;
			enum bool empty = false;
			void popFront() {
				front = uniform(worst, best, rng);
			}
		}
		Result result;
		result.popFront();
		return result;
	}
	return influencedChoiceCommon!true(luck, rng, uniformRange(rng, worst, best), worst, best);
}

@safe pure unittest {
	import std.random : Random;
	Random rand;
	enum iterations = 100;
	double test(double luck, int min, int max) {
		long total;
		foreach (i; 0 .. iterations) {
			const value = influencedUniform(luck, rand, min, max);
			assert(value >= min);
			assert(value <= max);
			total += value;
		}
		return total / double(iterations);
	}
	assert(test(0.0, 0, 100) < test(1.0, 0, 100));
	assert(test(0.0, 0, 100) > test(-1.0, 0, 100));
	assert(test(double.infinity, 0, 100) == 100);
	assert(test(-double.infinity, 0, 100) == 0);
	assert(test(0.0, 0, 100) > test(-1.0, 0, 100));
}
