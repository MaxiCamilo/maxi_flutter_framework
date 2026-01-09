import 'package:flutter/material.dart';
import 'package:maxi_framework/maxi_framework.dart';
import 'package:provider/provider.dart';

extension OrationProvideExtension on Oration {
  CacheOration translateFromProvider({required BuildContext context, required Oration? original}) {
    final translator = context.read<TranslatorForOrations>();
    if (original == null) {
      return CacheOration(translator: translator, originalOration: emptyOration);
    }

    if (original.hashCode == hashCode) {
      return this as CacheOration;
    } else {
      return CacheOration.parse(translator: translator, oration: original);
    }
  }
}

extension CacheOrationExtension on CacheOration? {
  CacheOration initFromProvider({required BuildContext context, Oration? oration}) {
    final translator = context.read<TranslatorForOrations>();
    if (this == null) {
      return CacheOration(translator: translator, originalOration: oration ?? emptyOration);
    } else {
      if (this!.hashCode == oration?.hashCode) {
        return this!;
      } else {
        return CacheOration(translator: translator, originalOration: oration ?? emptyOration);
      }
    }
  }
}
