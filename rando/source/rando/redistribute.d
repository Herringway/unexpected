module rando.redistribute;

import std.random : Random;

struct Redistributable {
	string group = "default";
}
struct Weight {
	double amount;
}

void redistribute(T...)(ref T values, double[] weights, ref Random rng) {
    import std.algorithm : sum;
    import std.math : round;
    import std.numeric : normalize;
	import std.random : uniform;
	double total = 0.0;
    double[] dist = weights.dup;
    const weightSum = weights.sum;
	static foreach (Idx, F; T) {
		total += values[Idx] / weights[Idx];
        weights[Idx] = uniform(0.0, 1.0, rng);
	}
    normalize!(double[])(weights, weightSum);
    normalize!(double[])(dist, total);
    foreach (Idx, ref value; values) {
        value = cast(typeof(value))round(dist[Idx] * weights[Idx]);
    }
}
