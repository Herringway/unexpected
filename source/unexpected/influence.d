/// Functions for "luck", or influenced results
module unexpected.influence;

auto influencedChoice(Range, Rand)(double luck, Rand rng, Range range) {
	import std.algorithm.comparison : min;
	import std.random : uniform01;
	assert(!range.empty, "Nothing to choose!");
	auto chosen = range.front;
	range.popFront();
	bool negative = luck < 0.0;
	if (luck < 0.0) {
		luck = -luck;
	}
	while ((luck > 0.0) && !range.empty) {
		const remaining = min(luck, 1.0);
		luck -= remaining;
		if (remaining >= uniform01(rng)) {
			auto next = range.front;
			range.popFront();
			if (negative ^ (next.value > chosen.value)) {
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
		int x;
		int value() const pure @safe {
			return x;
		}
	}
	Random rand;
	enum iterations = 10000;
	double test(double luck) {
		long total;
		foreach (i; 0 .. iterations) {
			total += influencedChoice(luck, rand, generate!(() => Result(uniform(0, 100, rand)))).x;
		}
		return total / double(iterations);
	}
	assert(test(0.0) < test(1.0));
	assert(test(0.0) > test(-1.0));
}
