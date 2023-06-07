///
module pcg;

import std.meta : AliasSeq;
import std.random : isUniformRNG;
import std.traits : isIntegral;

private V rotr(V)(V value, uint r) {
	return cast(V)(value >> r | value << (-r & (V.sizeof * 8 - 1)));
}

struct PCGConsts(X, I) {
	import std.math.exponential : log2;
	enum spareBits = (I.sizeof - X.sizeof) * 8;
	enum wantedOpBits = cast(uint)log2(X.sizeof * 8.0);
	struct xshrr {
		enum opBits = spareBits >= wantedOpBits ? wantedOpBits : spareBits;
		enum amplifier = wantedOpBits - opBits;
		enum xShift = (opBits + X.sizeof * 8) / 2;
		enum mask = (1 << opBits) - 1;
		enum bottomSpare = spareBits - opBits;
	}
	struct xshrs {
		// there must be a simpler way to express this
		static if (spareBits - 5 >= 64) {
			enum opBits = 5;
		} else static if (spareBits - 4 >= 32) {
			enum opBits = 4;
		} else static if (spareBits - 3 >= 16) {
			enum opBits = 3;
		} else static if (spareBits - 2 >= 4) {
			enum opBits = 2;
		} else static if (spareBits - 1 >= 1) {
			enum opBits = 1;
		} else {
			enum opBits = 0;
		}
		enum xShift = opBits + ((X.sizeof * 8) + mask) / 2;
		enum mask = (1 << opBits) - 1;
		enum bottomSpare = spareBits - opBits;
	}
	struct xsh {
		enum topSpare = 0;
		enum bottomSpare = spareBits - topSpare;
		enum xShift = (topSpare + X.sizeof * 8) / 2;
	}
	struct xsl {
		enum topSpare = spareBits;
		enum bottomSpare = spareBits - topSpare;
		enum xShift = (topSpare + X.sizeof * 8) / 2;
	}
	struct rxs {
		enum shift = (I.sizeof - X.sizeof) * 8;
		// there must be a simpler way to express this
		static if (shift > 64 + 8) {
			enum rShiftAmount = I.sizeof - 6;
			enum rShiftMask = 63;
		} else static if (shift > 32 + 4) {
			enum rShiftAmount = I.sizeof - 5;
			enum rShiftMask = 31;
		} else static if (shift > 16 + 2) {
			enum rShiftAmount = I.sizeof - 4;
			enum rShiftMask = 15;
		} else static if (shift > 8 + 1) {
			enum rShiftAmount = I.sizeof - 3;
			enum rShiftMask = 7;
		} else static if (shift > 4 + 1) {
			enum rShiftAmount = I.sizeof - 2;
			enum rShiftMask = 3;
		} else static if (shift > 2 + 1) {
			enum rShiftAmount = I.sizeof - 1;
			enum rShiftMask = 1;
		} else {
			enum rShiftAmount = 0;
			enum rShiftMask = 0;
		}
		enum extraShift = (X.sizeof - shift)/2;
	}
	struct rxsm {
		enum opBits = cast(uint)log2(X.sizeof * 8.0) - 1;
		enum shift = (I.sizeof - X.sizeof) * 8;
		enum mask = (1 << opBits) - 1;
	}
	struct xslrr {
		enum opBits = spareBits >= wantedOpBits ? wantedOpBits : spareBits;
		enum amplifier = wantedOpBits - opBits;
		enum mask = (1 << opBits) - 1;
		enum topSpare = spareBits;
		enum bottomSpare = spareBits - topSpare;
		enum xShift = (topSpare + X.sizeof * 8) / 2;
	}
}

private X xorshift(X, I)(I tmp, uint amt1, uint amt2) {
	tmp ^= tmp >> amt1;
	return cast(X)(tmp >> amt2);
}

/// XSH RR (xorshift high, random rotate) - decent performance, slightly better results
private X xshrr(X, I)(const I state) {
	alias constants = PCGConsts!(X, I).xshrr;
	static if (constants.opBits > 0) {
		auto rot = (state >> (I.sizeof * 8 - constants.opBits)) & constants.mask;
	} else {
		enum rot = 0;
	}
	uint amprot = cast(uint)((rot << constants.amplifier) & constants.mask);
	I tmp = state;
	return rotr(xorshift!X(tmp, constants.xShift, constants.bottomSpare), amprot);
}

/// XSH RS (xorshift high, random shift) - decent performance
private X xshrs(X, I)(const I state) {
	alias constants = PCGConsts!(X, I).xshrs;
	static if (constants.opBits > 0) {
		uint rshift = (state >> (I.sizeof * 8 - constants.opBits)) & constants.mask;
	} else {
		uint rshift = 0;
	}
	I tmp = state;
	return xorshift!X(tmp, constants.xShift, cast(uint)(constants.bottomSpare - constants.mask + rshift));
}

/// XSH (fixed xorshift, high) - don't use this for anything smaller than ulong
private X xsh(X, I)(const I state) {
	alias constants = PCGConsts!(X, I).xsh;

	I tmp = state;
	return xorshift!X(tmp, constants.xShift, constants.bottomSpare);
}

/// XSL (fixed xorshift, low) - don't use this for anything smaller than ulong
private X xsl(X, I)(const I state) {
	alias constants = PCGConsts!(X, I).xsl;

	I tmp = state;
	return xorshift!X(tmp, constants.xShift, constants.bottomSpare);
}

/// RXS (random xorshift)
private X rxs(X, I)(const I state) {
	alias constants = PCGConsts!(X, I).rxs;
	uint rshift = (state >> constants.rShiftAmount) & constants.rShiftMask;
	I tmp = state;
	return xorshift!X(tmp, cast(uint)(constants.shift + constants.extraShift - rshift), rshift);
}

/++
	RXS M XS (random xorshift, multiply, fixed xorshift)
	This has better statistical properties, but supposedly performs worse. This
	was not reproducible, however.
+/
private X rxsmxs(X, I)(const I state) {
	X result = rxsm!X(state);
	result ^= result >> ((2 * X.sizeof * 8 + 2) / 3);
	return result;
}

/// RXS M (random xorshift, multiply)
private X rxsm(X, I)(const I state) {
	alias constants = PCGConsts!(X, I).rxsm;
	I tmp = state;
	static if (constants.opBits > 0) {
		uint rshift = (tmp >> (I.sizeof * 8 - constants.opBits)) & constants.mask;
	} else {
		uint rshift = 0;
	}
	tmp ^= tmp >> (constants.opBits + rshift);
	tmp *= PCGMMultiplier!I;
	return cast(X)(tmp >> constants.shift);
}

/// DXSM (double xorshift, multiply) - newer, better performance for types 2x the size of the largest type the cpu can handle
private X dxsm(X, I)(const I state) {
	static assert(X.sizeof <= I.sizeof/2, "Output type must be half the size of the state type.");
	X hi = cast(X)(state >> ((I.sizeof - X.sizeof) * 8));
	X lo = cast(X)state;

	lo |= 1;
	hi ^= hi >> (X.sizeof * 8 / 2);
	hi *= PCGMMultiplier!I;
	hi ^= hi >> (3*(X.sizeof * 8 / 4));
	hi *= lo;
	return hi;
}
/// XSL RR (fixed xorshift, random rotate) - better performance for types 2x the size of the largest type the cpu can handle
private X xslrr(X, I)(const I state) {
	alias constants = PCGConsts!(X, I).xslrr;

	I tmp = state;
	static if (constants.opBits > 0) {
		uint rot = (tmp >> (I.sizeof * 8 - constants.opBits)) & constants.mask;
	} else {
		uint rot = 0;
	}
	uint amprot = (rot << constants.amplifier) & constants.mask;
	return rotr(xorshift!X(tmp, constants.xShift, constants.bottomSpare), amprot);
}

struct PCG(T, S, alias func, S multiplier = DefaultPCGMultiplier!S, S increment = DefaultPCGIncrement!S) {
	private S state;

	this(S val) @safe pure nothrow @nogc {
		seed(val);
	}
	void seed(S val) @safe pure nothrow @nogc {
		state = cast(S)(val + increment);
		popFront();
	}
	void popFront() @safe pure nothrow @nogc {
		state = cast(S)(state * multiplier + increment);
	}
	T front() const @safe pure nothrow @nogc @property {
		return func!T(state);
	}
	typeof(this) save() @safe pure nothrow @nogc {
		return this;
	}
	enum bool empty = false;
	enum bool isUniformRandom = true;
	enum T min = T.min;
	enum T max = T.max;
}

template DefaultPCGMultiplier(T) if (isIntegral!T) {
	static if (is(T == ubyte)) {
		enum DefaultPCGMultiplier = 141;
	} else static if (is(T == ushort)) {
		enum DefaultPCGMultiplier = 12829;
	} else static if (is(T == uint)) {
		enum DefaultPCGMultiplier = 747796405;
	} else static if (is(T == ulong)) {
		enum DefaultPCGMultiplier = 6364136223846793005;
	} else static if (is(T == ucent)) {
		//enum DefaultPCGMultiplier = 47026247687942121848144207491837523525;
	}
}

template DefaultPCGIncrement(T) if (isIntegral!T) {
	static if (is(T == ubyte)) {
		enum DefaultPCGIncrement = 77;
	} else static if (is(T == ushort)) {
		enum DefaultPCGIncrement = 47989;
	} else static if (is(T == uint)) {
		enum DefaultPCGIncrement = 2891336453;
	} else static if (is(T == ulong)) {
		enum DefaultPCGIncrement = 1442695040888963407;
	} else static if (is(T == ucent)) {
		//enum DefaultPCGIncrement = 117397592171526113268558934119004209487;
	}
}

private template PCGMMultiplier(T) if (isIntegral!T) {
	static if (is(T : ubyte)) {
		enum PCGMMultiplier = 217;
	} else static if (is(T : ushort)) {
		enum PCGMMultiplier = 62169;
	} else static if (is(T : uint)) {
		enum PCGMMultiplier = 277803737;
	} else static if (is(T : ulong)) {
		enum PCGMMultiplier = 12605985483714917081;
	//} else static if (is(T == ucent)) {
		//enum PCGMMultiplier = 327738287884841127335028083622016905945;
	}
}

alias SupportedTypes = AliasSeq!(ubyte, ushort, uint, ulong);
alias SupportedFunctions = AliasSeq!(xshrr, xshrs, xsh, xsl, rxs, rxsmxs, rxsm, xslrr);

import std.conv : text;
static foreach (ResultType; SupportedTypes) {
	static foreach (StateType; SupportedTypes) {
		static if (StateType.sizeof >= ResultType.sizeof) {
			static foreach (Function; SupportedFunctions) {
				mixin("alias PCG", text(StateType.sizeof * 8, ResultType.sizeof * 8, __traits(identifier, Function)), " = PCG!(ResultType, StateType, Function);");
			}
		}
	}
}
alias PCG6432dxsm = PCG!(uint, ulong, dxsm);

@safe unittest {
	import std.algorithm : reduce;
	import std.datetime.stopwatch : benchmark;
	import std.math : pow, sqrt;
	import std.random : isSeedable, Mt19937, uniform, uniform01, unpredictableSeed;
	import std.stdio : writefln, writeln;
	auto seed = unpredictableSeed;

	void testRNG(RNG, string name)(uint seed) {
		static if (isSeedable!(RNG, uint)) {
			auto rng = RNG(seed);
		} else static if (isSeedable!(RNG, ushort)) {
			auto rng = RNG(cast(ushort)seed);
		} else static if (isSeedable!(RNG, ubyte)) {
			auto rng = RNG(cast(ubyte)seed);
		}
		writefln!"--%s--"(name);
		double total = 0;
		ulong[ubyte] distribution;
		void test() {
			total += uniform01(rng);
			distribution.require(uniform!ubyte(rng), 0)++;
		}
		auto result = benchmark!(test)(1000000)[0];
		writefln!"Benchmark completed in %s"(result);
		writeln(total);
		double avg = reduce!((a, b) => a + b / distribution.length)(0.0f, distribution);
		auto var = reduce!((a, b) => a + pow(b - avg, 2) / distribution.length)(0.0f, distribution);
		auto sd = sqrt(var);
		writefln!"Average: %s, Standard deviation: %s"(avg, sd);
	}

	testRNG!(PCG168xshrr, "PCG168xshrr")(seed);
	testRNG!(PCG3216xshrr, "PCG3216xshrr")(seed);
	testRNG!(PCG6432xslrr, "PCG6432xslrr")(seed);
	testRNG!(PCG648rxsmxs, "PCG648rxsmxs")(seed);
	testRNG!(PCG6432dxsm, "PCG6432dxsm")(seed);
	testRNG!(Mt19937, "Mt19937")(seed);
}