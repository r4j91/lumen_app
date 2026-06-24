# Lúmen — Roadmap de Implementação

| Fase | Objetivo | Status |
|------|----------|--------|
| 0 | Setup do ambiente | Concluído |
| 1 | Tema + navegação (bottom nav, 5 abas) | Concluído |
| 2 | Tela "Hoje" com lista de tarefas (dados mockados) | Concluído |
| 3 | Swipe actions + menu de contexto | Concluído |
| 4 | Subtarefas expansíveis + preview de descrição | Concluído |
| 5 | Conectar Supabase (CRUD) | Concluído |
| 6 | Autenticação multiusuário | Concluído |
| 7 | Telas restantes + layout responsivo | Em andamento |
| 8 | Build Android + Web | Pendente |
| 9 | Testes em dispositivos reais | Pendente |
| 10 | Distribuição | Pendente |

## Fase 2 — Tela "Hoje" (próximo passo)

Construir lib/screens/today_screen.dart com:
- Cabeçalho: título "Hoje" (estilo headlineLarge), data por extenso (ex: "Sábado, 13 de Junho"), e linha "Meu dia · N tarefas"
- Lista de tarefas (ListView) com layout compacto por item:
  - Indicador de prioridade: círculo ~18px com borda colorida (3px) na cor da prioridade
  - Título da tarefa (titleMedium)
  - Nome do projeto (bodyMedium, cor secundária)
  - Horário, se houver (à direita do título, com ícone de relógio pequeno)
  - Descrição: uma linha de preview truncada (se houver)
  - Tags: chips pequenos arredondados com cores próprias (máx. 2 visíveis + "+N")
  - Se houver subtarefas: contador "X/Y" + botão de expandir (apenas visual nesta fase, sem funcionalidade ainda — isso vem na Fase 4)

Criar um modelo simples lib/models/task.dart com os campos: id, title, project, priority (enum: high/medium/low), time (nullable), description (nullable), tags (List<String>), subtasksDone, subtasksTotal.

Popular a tela com estes 5 dados de exemplo (em memória, sem Supabase ainda):
1. "Revisar feedback de design" — prioridade alta, projeto "Trabalho", tags ["Importante","Em Andamento"], descrição "Aplicar os ajustes do Figma e validar com o time antes da reunião.", subtarefas 5/5
2. "Reunião com Martin" — prioridade média, projeto "Trabalho", horário "11:00", descrição "Discutir o progresso da sprint e os próximos passos do roadmap."
3. "Comprar mantimentos" — prioridade baixa, projeto "Pessoais"
4. "Planejar viagem de fim de semana" — prioridade baixa, projeto "Pessoais", descrição "Definir roteiro, hospedagem e orçamento para o feriado.", subtarefas 1/4
5. "Lançar nova landing page" — prioridade alta, projeto "Trabalho", tags ["Importante"], subtarefas 3/5

Conectar essa tela como a aba "Hoje" do RootScreen (lib/main.dart), substituindo o placeholder de texto atual.

Depois de criar os dois arquivos, leia-os e implemente a Fase 2 conforme descrito. O app já está rodando com flutter run -d chrome no terminal integrado — não rode flutter run novamente, apenas confirme quando estiver pronto para eu dar hot reload com "r".

## Fase 7 — Telas restantes + layout responsivo (mobile/web)

### 7.0 — Layout responsivo (base para todas as telas)
Criar lib/widgets/responsive_layout.dart com um widget que detecta o tamanho da tela via LayoutBuilder:
- Mobile (largura < 600px): layout atual com bottom nav (NavigationBar)
- Desktop/Web (largura >= 600px): layout com NavigationRail fixa à esquerda (ícones + labels) e conteúdo à direita ocupando o restante da tela
Atualizar RootScreen em main.dart para usar ResponsiveLayout em vez de Scaffold com bottom nav diretamente.

### 7.1 — Tela "Em breve" (lib/screens/upcoming_screen.dart)
- Calendário mensal no topo (usar table_calendar package)
- Ao tocar em uma data, filtra as tarefas abaixo para mostrar só as daquela data
- Tarefas agrupadas por data (seções "Amanhã", "Seg, 16 Jun", etc.)
- Reutilizar SwipeableTaskTile
- Buscar do Supabase: tasks com data_vencimento não nula, ordenadas por data_vencimento

### 7.2 — Tela "Projetos" (lib/screens/projects_screen.dart)
- Lista de projetos do usuário logado
- Card: ícone, nome, descrição truncada, barra de progresso, contagem "X de Y tarefas"
- Botão "+ Adicionar" abre bottom sheet com nome e cor
- Tocar num projeto vai para ProjectDetailScreen

### 7.3 — Tela "Filtros" / Inbox (lib/screens/inbox_screen.dart)
- Tarefas sem projeto vinculado (project_id is null) ou sem data
- Campo "Adicionar tarefa" proeminente no topo

### 7.4 — Tela "Perfil" — melhorar placeholder atual
- Avatar com iniciais em círculo cor accent
- E-mail do usuário
- Seção "Preferências" (placeholder)
- Botão "Sair" mantido

## Fase 6 — Autenticação multiusuário (parte 1: tela de login + fluxo)

1. Criar lib/screens/auth_screen.dart: tela de login/cadastro seguindo o design system (app_colors.dart, app_theme.dart):
   - Logo/título "Lúmen" no topo
   - Campo de e-mail e campo de senha (obscureText)
   - Botão principal: "Entrar" (modo login) ou "Criar conta" (modo cadastro)
   - Texto pequeno abaixo alternando entre os modos: "Não tem conta? Criar conta" / "Já tem conta? Entrar"
   - Mensagem de erro (texto vermelho) caso a autenticação falhe
   - Indicador de carregamento no botão durante a chamada

2. Criar lib/services/auth_service.dart com:
   - signIn(email, senha) usando supabase.auth.signInWithPassword
   - signUp(email, senha) usando supabase.auth.signUp
   - signOut() usando supabase.auth.signOut
   - um Stream<AuthState> exposto a partir de supabase.auth.onAuthStateChange

3. Atualizar lib/main.dart: o widget raiz deve escutar o estado de autenticação via StreamBuilder. Se não houver sessão ativa, mostrar AuthScreen. Se houver sessão, mostrar RootScreen.

4. Na tela Perfil (atualmente placeholder), adicionar e-mail do usuário logado e botão "Sair".

## Fase 5 — Conectar Supabase (CRUD básico, sem auth)

1. Adicionar supabase_flutter ao pubspec.yaml e rodar flutter pub get.
2. Inicializar o Supabase em main.dart com Supabase.initialize(url: 'https://gbpoenvogrcqhcqfjldd.supabase.co', anonKey: '...') antes de runApp.
3. Criar lib/services/supabase_client.dart com um getter global `supabase` (SupabaseClient) para acesso fácil em qualquer parte do app.
4. Criar lib/services/task_repository.dart com um método fetchTodayTasks() que busca da tabela tasks com join de projects, embed de subtasks e task_labels->labels, mapeando para List<Task>.
5. Atualizar TodayScreen: carregar dados via TaskRepository().fetchTodayTasks() no initState, mostrando CircularProgressIndicator enquanto busca.
6. Manter a UI exatamente igual — só troca a origem dos dados.

## Fase 4 — Subtarefas expansíveis

1. Criar lib/models/subtask.dart: classe Subtask com campos title (String) e done (bool).
2. Adicionar campo subtasks: List<Subtask> ao modelo Task.
3. Popular _mockTasks com subtarefas:
   - "Revisar feedback de design" (5/5, todas done=true): "Ler comentários do Figma", "Ajustar paleta de cores", "Revisar tipografia", "Exportar protótipo atualizado", "Compartilhar com o time"
   - "Planejar viagem de fim de semana" (1/4): "Definir destino" (done=true), "Reservar hospedagem", "Planejar roteiro", "Definir orçamento" (done=false)
   - "Lançar nova landing page" (3/5): "Wireframe da página", "Conteúdo e copy", "Design visual" (done=true), "Implementar seção hero", "Testes responsivos" (done=false)
4. Tornar a linha do contador de subtarefas ("X/Y ⌄") clicável: ao tocar, expande/colapsa a lista de subtarefas abaixo do card, com animação suave (AnimatedSize ou AnimatedContainer, Curves.easeInOut, ~250ms). O chevron gira 180° ao expandir (AnimatedRotation).
5. Cada subtarefa expandida: checkbox + título, levemente recuado. Texto com strikethrough quando done=true. Tocar no checkbox alterna o estado localmente (sem persistência ainda — isso é Fase 5).

## Fase 3 — Swipe actions + menu de contexto

1. Adicionar flutter_slidable ao pubspec.yaml.
2. Criar lib/widgets/swipeable_task_tile.dart: envolver o card de tarefa com Slidable, endActionPane com 3 ações (Concluir/verde/check, Adiar/amarelo/relógio, Excluir/vermelho/lixeira), usando cores de app_colors.dart. Por enquanto cada ação só mostra SnackBar de confirmação.
3. Criar lib/widgets/task_context_menu.dart: overlay customizado ativado por long-press (mobile) e clique direito (desktop/web). Painel principal: Editar, Marcar como concluída, Adiar, Duplicar, separador, "Prioridade: [valor] ›", "Etiquetas (N) ›", "Mover para: [projeto] ›" (cada um abre sub-painel ao tocar), separador, Excluir (vermelho). Sub-painéis com seleção (radio para prioridade/projeto, checkbox para etiquetas). Posicionamento clamped à tela, max-height ~70vh com scroll interno, fecha ao tocar fora/Esc.
4. Conectar SwipeableTaskTile + long-press/clique-direito no menu de contexto, em cada item da lista "Hoje".
