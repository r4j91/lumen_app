import 'dart:async';
import 'package:flutter/foundation.dart';

/// Notifica telas em cache ([IndexedStack]) quando tarefas mudam em qualquer aba.
///
/// Contrato atual: cada tela guarda sua própria lista e recarrega do Supabase
/// ao ouvir [notifyChanged]. Debounce de 180 ms evita rajadas de queries.
///
/// Migração futura: substituir por Riverpod `ref.invalidate` — ver
/// [DATA_LAYER.md](DATA_LAYER.md).
class TaskSync {
  TaskSync._();
  static final TaskSync instance = TaskSync._();

  final _listeners = <VoidCallback>{};
  Timer? _debounce;

  void addListener(VoidCallback listener) => _listeners.add(listener);

  void removeListener(VoidCallback listener) => _listeners.remove(listener);

  /// Agrupa rajadas de mudanças (ex.: criar tarefa + fechar sheet) em um
  /// único ciclo de reload, evitando 5+ queries simultâneas por aba.
  void notifyChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 180), () {
      for (final listener in List<VoidCallback>.of(_listeners)) {
        listener();
      }
    });
  }
}
