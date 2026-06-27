# Stacked — Contexto do Projeto

## Visão Geral
App de gerenciamento de tarefas estilo Todoist/Things 3, sendo reconstruído do zero em Flutter (anteriormente era um PWA em React/Tailwind).

## Stack
- Flutter (Dart) — iOS, Android, Web e macOS a partir de um único código
- Supabase — banco de dados, autenticação e sincronização (conectar na Fase 5)
- Riverpod — gerenciamento de estado (adicionar quando necessário)
- go_router — navegação (adicionar na Fase 7)

## Design System

### Paleta de cores (lib/theme/app_colors.dart)
- Fundo: #1A1B1E
- Superfície: #242529
- Superfície variante: #2C2D33
- Texto primário: #F2F3F5
- Texto secundário: #9296A0
- Texto terciário: #6B6E76
- Destaque (accent): #5FD3DC
- Prioridade alta: #EF5A5F
- Prioridade média: #F5A623
- Prioridade baixa: #4D9FEC
- Tag roxo (Ideia): #B18CF5
- Tag verde (Em Andamento): #8FD46B

### Tipografia e densidade
- Fonte do sistema (padrão do Flutter)
- Linhas de tarefa compactas (~52-56px de altura)
- Título de tela: 30px, weight 800
- Título de tarefa: 15.5px, weight 600
- Texto secundário (projeto/descrição): ~12.5-13px

### Telas (bottom navigation, 5 abas)
1. Hoje — lista de tarefas do dia
2. Em breve — calendário + próximas tarefas
3. Projetos — lista de projetos com progresso
4. Filtros — repensar como "Inbox real" (tarefas sem projeto/data) no futuro
5. Perfil — configurações e dados do usuário

## Estrutura de pastas
lib/
  main.dart
  theme/ (app_colors.dart, app_theme.dart)
  models/ (task.dart, project.dart, label.dart, subtask.dart)
  services/ (supabase_client.dart, task_repository.dart)
  screens/ (today_screen.dart, upcoming_screen.dart, projects_screen.dart, filters_screen.dart, profile_screen.dart)
  widgets/ (task_tile.dart, swipeable_task.dart, task_context_menu.dart, subtask_list.dart, bottom_nav.dart)

## Bugs conhecidos e soluções (não repetir)

### AnimatedSize + SizeTransition simultâneos causam salto de conteúdo
`AnimatedSize` anima *qualquer* mudança de tamanho do filho, incluindo mudanças causadas por `SizeTransition` internos. Se um card usa `AnimatedSize` para colapsar na conclusão E um `SizeTransition` interno para expandir subtarefas, os dois animam a altura ao mesmo tempo → conteúdo "salta".
**Solução:** nunca usar `AnimatedSize` como wrapper externo quando há animações de altura internas. Usar `SizeTransition` com `AnimationController` dedicado, iniciado em `value: 1.0`, acionado explicitamente apenas quando necessário (ex: conclusão de tarefa).

### onTapDown em GestureDetector interno não bloqueia o pai
`onTapDown` dispara em todos os listeners da árvore imediatamente, antes do gesture arena. Adicionar `onTapDown: (_) {}` num GestureDetector filho **não** impede o pai de receber o evento. Para isolar completamente o toque, mover o widget para fora da árvore do pai (sibling em vez de filho).

### SafeArea dentro de showModalBottomSheet causa salto de animação
`SafeArea` lê `MediaQuery.viewInsets` (altura do teclado). Quando o teclado fecha enquanto o sheet abre, o padding muda no meio da animação → itens "saltam". Substituir `SafeArea` por `SizedBox(height: 8 + MediaQuery.of(ctx).viewPadding.bottom)`.

### Hero animations em listas de tarefas
Testado e causou problemas visuais nas listas. **Nunca usar Hero animations** neste projeto.

### Coluna descricao na tabela subtasks
A coluna `descricao text` precisa existir no Supabase antes de incluí-la em queries. Migration: `ALTER TABLE subtasks ADD COLUMN IF NOT EXISTS descricao text;`. Sem ela, qualquer SELECT que inclua `descricao` retorna erro e a tela fica em branco.

## Workflow de validação visual (economia de tokens)
Após editar UI: rodar `flutter analyze` no(s) arquivo(s) tocado(s) e parar — isso já garante correção estrutural. **NÃO** relançar o simulador, navegar por `idb`/`xcrun simctl` e tirar/ler screenshots por padrão a cada ajuste pontual — cada screenshot lido consome muitos tokens (visão), e ajustes pequenos (raio, cor, padding, remover/restaurar um trecho) raramente precisam de confirmação visual para serem considerados corretos. Só fazer o ciclo completo (rebuild → screenshot → ler) quando o usuário pedir explicitamente ("tirar screenshot", "mostrar resultado", "validar visualmente") ou quando a mudança for estrutural/arriscada o suficiente para justificar.

## Padrões de interação alvo
- Swipe para a esquerda no item de tarefa revela: Concluir (verde), Adiar (amarelo), Excluir (vermelho). Threshold de ~60-80px, com direction lock para não conflitar com scroll vertical.
- Long-press (ou clique direito no desktop/web) abre menu de contexto compacto: Editar, Concluir, Adiar, Duplicar, depois linhas resumidas "Prioridade: Alta ›", "Etiquetas (N) ›", "Mover para: Projeto ›" que expandem em sub-painéis ao tocar, e por fim Excluir (vermelho).
- Botão de expandir (chevron) ao lado do contador de subtarefas (ex: "5/5") expande a lista de subtarefas inline, sem navegar de tela, com animação fluida (preferir grid/clip ao invés de height: auto).
- Tarefas com descrição mostram uma linha de preview (truncada com ellipsis) abaixo do título.
