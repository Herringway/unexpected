module rando.palette;

import reversineer;
import magicalrainbows.formats;
import std.random : Random, uniform;

import rando.common;

enum ColourRandomizationLevel {
	randomHue,
	shiftHue,
	multHue,
	shiftInverseHue,
	multInverseHue,
	randomSaturation,
	shiftSaturation,
	multSaturation,
	shiftInverseSaturation,
	multInverseSaturation,
	randomValue,
	shiftValue,
	multValue,
	shiftInverseValue,
	multInverseValue,
	absurd,
	extreme
}

T[] randomizePalette(T)(T[] input, ColourRandomizationLevel randomizationLevel, uint seed) {
	import std.algorithm.iteration : map;
	import std.algorithm.comparison : min;
	import std.array : array;
	import std.random : Random, uniform01;

	auto rand = Random(seed);
	const randomConstantH0 = rand.uniform01();
	const randomConstantH1 = rand.uniform01();
	const randomConstantH2 = rand.uniform01();
	const randomConstantS0 = rand.uniform01();
	const randomConstantS1 = rand.uniform01();
	const randomConstantS2 = rand.uniform01();
	const randomConstantV0 = rand.uniform01();
	const randomConstantV1 = rand.uniform01();
	const randomConstantV2 = rand.uniform01();
	HSVA!float genRandomHSV(HSVA!float input, ColourRandomizationLevel level) {
		bool shiftHue;
		bool multHue;
		bool randomizeHue;
		bool invertHue;
		bool shiftSaturation;
		bool multSaturation;
		bool randomizeSaturation;
		bool invertSaturation;
		bool shiftValue;
		bool multValue;
		bool randomizeValue;
		bool invertValue;
		bool useRGB;
		final switch (randomizationLevel) {
			case ColourRandomizationLevel.shiftHue:
				shiftHue = true;
				break;
			case ColourRandomizationLevel.multHue:
				multHue = true;
				break;
			case ColourRandomizationLevel.shiftInverseHue:
				invertHue = true;
				shiftHue = true;
				break;
			case ColourRandomizationLevel.multInverseHue:
				invertHue = true;
				multHue = true;
				break;
			case ColourRandomizationLevel.randomHue:
				randomizeHue = true;
				break;
			case ColourRandomizationLevel.randomSaturation:
				randomizeSaturation = true;
				break;
			case ColourRandomizationLevel.shiftSaturation:
				shiftSaturation = true;
				break;
			case ColourRandomizationLevel.multSaturation:
				multSaturation = true;
				break;
			case ColourRandomizationLevel.shiftInverseSaturation:
				invertSaturation = true;
				shiftSaturation = true;
				break;
			case ColourRandomizationLevel.multInverseSaturation:
				invertSaturation = true;
				multSaturation = true;
				break;
			case ColourRandomizationLevel.randomValue:
				randomizeValue = true;
				break;
			case ColourRandomizationLevel.shiftValue:
				shiftValue = true;
				break;
			case ColourRandomizationLevel.multValue:
				multValue = true;
				break;
			case ColourRandomizationLevel.shiftInverseValue:
				invertValue = true;
				shiftValue = true;
				break;
			case ColourRandomizationLevel.multInverseValue:
				invertValue = true;
				multValue = true;
				break;
			case ColourRandomizationLevel.absurd:
				randomizeHue = true;
				randomizeSaturation = true;
				randomizeValue = true;
				break;
			case ColourRandomizationLevel.extreme:
				useRGB = true;
				break;
		}
		if (useRGB) {
			return RGB888(
				rand.uniform!ubyte(),
				rand.uniform!ubyte(),
				rand.uniform!ubyte()
			).toHSVA!float;
		} else {
			float hue = input.hue;
			float saturation = input.saturation;
			float value = input.value;
			if (randomizeHue) {
				hue = randomConstantH0;
			}
			if (randomizeSaturation) {
				saturation = randomConstantS0;
			}
			if (randomizeValue) {
				value = randomConstantV0;
			}
			if (shiftHue) {
				hue += randomConstantH1;
			}
			if (invertHue) {
				hue = 1.0 - hue;
			}
			if (invertSaturation) {
				saturation = 1.0 - saturation;
			}
			if (invertValue) {
				value = 1.0 - value;
			}
			if (multHue) {
				hue *= randomConstantH2 * 2.0;
			}
			if (shiftSaturation) {
				hue += randomConstantS1;
			}
			if (multSaturation) {
				hue *= randomConstantS2 * 2.0;
			}
			if (shiftValue) {
				value += randomConstantV1;
			}
			if (multValue) {
				value *= randomConstantV2 * 2.0;
			}
			return HSVA!float(hue % 1.0, saturation % 1.0, value % 1.0, input.alpha);
		}
	}
	return input.map!(x => x.toHSVA!float).map!(x => genRandomHSV(x, randomizationLevel)).map!(x => x.toRGB!(T, float)).array;
}

void randomizePalette(Palette paletteOptions, T)(ref T field, ref Random rng, ref uint seed, const Options options) {
	if (!paletteOptions.shareSeed) {
		seed = rng.uniform!uint;
	}
	const start = paletteOptions.dontSkipFirst ? 0 : 1;
	field[start .. $] = randomizePalette(field[start .. $], options.colourRandomizationStyle, seed);
}
