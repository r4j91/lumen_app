import 'package:flutter/services.dart';

class HapticService {
  static final HapticService _instance = HapticService._internal();
  factory HapticService() => _instance;
  HapticService._internal();

  // Completar tarefa — 3 tempos crescente
  Future<void> taskCompleted() async {
    await HapticFeedback.lightImpact();
    await Future.delayed(const Duration(milliseconds: 80));
    await HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 80));
    await HapticFeedback.heavyImpact();
  }

  // Criar tarefa — dois toques ascendentes
  Future<void> taskCreated() async {
    await HapticFeedback.lightImpact();
    await Future.delayed(const Duration(milliseconds: 60));
    await HapticFeedback.mediumImpact();
  }

  // Excluir tarefa — toque forte descendente
  Future<void> taskDeleted() async {
    await HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 50));
    await HapticFeedback.mediumImpact();
  }

  // Trocar aba — snap preciso
  Future<void> tabChanged() async {
    await HapticFeedback.selectionClick();
  }

  // Swipe threshold atingido — crescente
  Future<void> swipeThreshold() async {
    await HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 40));
    await HapticFeedback.heavyImpact();
  }

  // Arrastar subtarefa — encaixe leve
  Future<void> dragSnap() async {
    await HapticFeedback.selectionClick();
  }

  // Abrir FAB — expansivo suave
  Future<void> fabOpened() async {
    await HapticFeedback.lightImpact();
    await Future.delayed(const Duration(milliseconds: 60));
    await HapticFeedback.lightImpact();
    await Future.delayed(const Duration(milliseconds: 60));
    await HapticFeedback.mediumImpact();
  }

  // Selecionar prioridade — clique preciso
  Future<void> prioritySelected() async {
    await HapticFeedback.selectionClick();
  }

  // Selecionar data no calendário — toque leve
  Future<void> dateSelected() async {
    await HapticFeedback.lightImpact();
  }

  // Confirmar data (atalho rápido) — toque médio + leve
  Future<void> dateConfirmed() async {
    await HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 50));
    await HapticFeedback.lightImpact();
  }

  // Favoritar projeto — padrão estrela
  Future<void> projectFavorited() async {
    await HapticFeedback.lightImpact();
    await Future.delayed(const Duration(milliseconds: 40));
    await HapticFeedback.lightImpact();
    await Future.delayed(const Duration(milliseconds: 40));
    await HapticFeedback.mediumImpact();
  }

  // Salvar — confirmação suave
  Future<void> saved() async {
    await HapticFeedback.mediumImpact();
  }

  // Erro — padrão negativo
  Future<void> error() async {
    await HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    await HapticFeedback.heavyImpact();
  }

  // Toque genérico de seleção
  Future<void> selectionClick() async {
    await HapticFeedback.selectionClick();
  }

  // Toque leve genérico
  Future<void> lightImpact() async {
    await HapticFeedback.lightImpact();
  }
}
