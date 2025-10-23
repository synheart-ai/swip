import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart' show rootBundle;
import 'on_device_model.dart';

class JsonLinearModel implements OnDeviceModel {
  final List<double> _w;
  final double _b;
  final List<double> _mean, _std;
  final bool _useSigmoid;
  final double _sa, _sb;
  @override
  final ModelInfo info;

  JsonLinearModel._(
    this._w,
    this._b,
    this._mean,
    this._std,
    this._useSigmoid,
    this._sa,
    this._sb,
    this.info,
  );

  static Future<JsonLinearModel> loadFromAsset(String assetPath) async {
    final text = await rootBundle.loadString(assetPath);
    final m = json.decode(text) as Map<String, dynamic>;
    final schema =
        List<String>.from(m['schema']['input_names'] as List<dynamic>);
    final mean = (m['schema']['normalization']['mean'] as List)
        .map((e) => (e as num).toDouble())
        .toList();
    final std = (m['schema']['normalization']['std'] as List)
        .map((e) => (e as num).toDouble())
        .toList();
    final w = (m['w'] as List).map((e) => (e as num).toDouble()).toList();
    final b = (m['b'] as num).toDouble();
    final inf = (m['inference'] ?? {}) as Map<String, dynamic>;
    final useSig = (inf['score_fn'] ?? 'sigmoid') == 'sigmoid';
    final sa = (inf['sigmoid_a'] ?? 1.0).toDouble();
    final sb = (inf['sigmoid_b'] ?? 0.0).toDouble();
    final checksum = (m['checksum']?['value'] ?? '') as String;
    final id = m['model_id'] as String;
    final fmt = m['format'] as String;

    return JsonLinearModel._(
      w,
      b,
      mean,
      std,
      useSig,
      sa,
      sb,
      ModelInfo(
        id: id,
        type: fmt,
        checksum: checksum,
        inputSchema: schema,
      ),
    );
  }

  @override
  double predict(List<double> x) {
    // z-score normalize
    final xn = List<double>.generate(x.length, (i) {
      final mu = i < _mean.length ? _mean[i] : 0.0;
      final sd = i < _std.length ? _std[i] : 1.0;
      final v = x[i];
      return (v.isNaN || sd == 0.0) ? 0.0 : (v - mu) / sd;
    });

    // margin
    double m = _b;
    for (var i = 0; i < _w.length && i < xn.length; i++) {
      m += _w[i] * xn[i];
    }

    // probability
    if (_useSigmoid) {
      final s = _sa * m + _sb;
      return 1.0 / (1.0 + exp(-s));
    } else {
      return 1.0 / (1.0 + exp(-m));
    }
  }
}
