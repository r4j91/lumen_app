---
name: Lumen
description: Gerenciador de tarefas pessoal, dark-mode-first, estilo Todoist/Things 3
colors:
  background-graphite: "#1A1B1E"
  surface-graphite: "#242529"
  surface-variant-graphite: "#2C2D33"
  text-primary-graphite: "#F2F3F5"
  text-secondary-graphite: "#9296A0"
  text-tertiary-graphite: "#6B6E76"
  accent-cyan: "#5FD3DC"
  priority-high: "#EF5A5F"
  priority-medium: "#F5A623"
  priority-low: "#4D9FEC"
  tag-purple: "#B18CF5"
  tag-green: "#8FD46B"
typography:
  title:
    fontFamily: "system default (San Francisco / Roboto)"
    fontSize: "30px"
    fontWeight: 800
  body:
    fontFamily: "system default"
    fontSize: "15.5px"
    fontWeight: 600
  support:
    fontFamily: "system default"
    fontSize: "12.5px"
    fontWeight: 400
rounded:
  sm: "8px"
  md: "12px"
  lg: "16px"
  xl: "20px"
  xxl: "28px"
  pill: "999px"
spacing:
  xs: "4px"
  sm: "8px"
  md: "12px"
  lg: "16px"
  xl: "20px"
  xxl: "24px"
  xxxl: "32px"
  hero: "48px"
components:
  card-overdue:
    backgroundColor: "{colors.surface-graphite}"
    rounded: "{rounded.xl}"
  task-tile:
    height: "52-56px"
    rounded: "{rounded.md}"
  chip-tag:
    rounded: "{rounded.pill}"
---

# Design System: Lumen

## 1. Overview

**Creative North Star: "The Quiet Control Room"**

Lumen é um painel de controle silencioso: alta densidade de informação organizada em camadas de tom escuro, onde nada compete por atenção sem necessidade. O sistema rejeita explicitamente o Todoist genérico colorido-demais (cores saturadas espalhadas sem hierarquia), o Notion denso-de-blocos (excesso de opções por item, navegação lenta) e qualquer gamificação visual (confete, badges, streaks, sons de recompensa). Densidade não é minimalismo vazio — é organização: linhas de tarefa compactas (~52-56px), tipografia com pesos diferenciados, e um único accent cyan usado com moderação para indicar interatividade e estado, não decoração.

**Key Characteristics:**
- Dark mode como cidadão de primeira classe (5 temas: graphite/moonstone/midnight/obsidian/slate — graphite é o padrão)
- Profundidade por camadas de tom (background → surface → surfaceVariant), não por sombra projetada
- Um accent por tema, usado com moderação — nunca múltiplas cores saturadas competindo
- Linhas de conteúdo compactas e densas, mas com respiro suficiente pra escanear rápido
- Microinterações sutis (swipe, long-press, animação de conclusão) carregam a sensação de qualidade sem ser o ponto central

## 2. Colors

A paleta é construída em camadas de cinza-azulado escuro (tema graphite, padrão) com um único accent ciano. Outros 4 temas (moonstone claro, midnight, obsidian, slate) seguem a mesma estrutura de papéis, valores próprios.

### Primary
- **Accent Cyan** (`#5FD3DC`): único accent do tema graphite. Usado em botões de ação, estados selecionados, foco de borda, ícones interativos. Nunca em áreas grandes de fundo.

### Neutral
- **Background Graphite** (`#1A1B1E`): fundo base de toda tela.
- **Surface Graphite** (`#242529`): cards, sheets, navbar — primeira camada elevada sobre o background.
- **Surface Variant Graphite** (`#2C2D33`): segunda camada (inputs, divisores de hover, chips neutros).
- **Texto Primário** (`#F2F3F5`): títulos, texto de tarefa.
- **Texto Secundário** (`#9296A0`): metadados, descrições, contagens.
- **Texto Terciário** (`#6B6E76`): texto de suporte, placeholders, ícones inativos.

### Semantic (constantes, não mudam com o tema)
- **Prioridade Alta** (`#EF5A5F`): badge/borda de tarefa P1.
- **Prioridade Média** (`#F5A623`): P2.
- **Prioridade Baixa** (`#4D9FEC`): P3.
- **Tag Roxa** (`#B18CF5`): etiqueta "Ideia".
- **Tag Verde** (`#8FD46B`): etiqueta "Em Andamento".

### Named Rules
**The One Accent Rule.** Cada tema tem exatamente um accent. Ele aparece em ≤10% de qualquer tela — botão de ação, seleção, foco. Nunca dois accents competindo na mesma view.

**The Tonal Depth Rule.** Profundidade vem de três camadas de tom (background/surface/surfaceVariant), nunca de sombra projetada. Se um elemento precisa "flutuar", ele sobe uma camada de tom — não ganha box-shadow.

## 3. Typography

**Display/Title Font:** fonte padrão do sistema (San Francisco no iOS, Roboto no Android) — sem fonte customizada.
**Body Font:** mesma fonte do sistema, variando peso.
**Character:** uma única família tipográfica, hierarquia construída inteiramente por tamanho e peso (não por troca de fonte) — reforça a sensação de painel técnico unificado, não editorial.

### Hierarchy
- **Título de tela** (weight 800, 30px): cabeçalho de cada aba (Hoje, Em breve, Projetos...).
- **Título de tarefa** (weight 600, 15.5px): linha principal de cada item de lista.
- **Texto secundário** (weight 400, ~12.5-13px): nome de projeto, descrição, metadados.
- **Label/Badge** (weight 700, ~10-11px, letter-spacing ~0.5-0.8): "TAREFA ATRASADA", labels de seção em caixa alta — uso restrito a badges curtos.

### Named Rules
**The Weight-Not-Family Rule.** Hierarquia é peso e tamanho, nunca troca de família tipográfica. Uma fonte, múltiplos pesos.

## 4. Elevation

Lumen é tonal, não sombreado. Profundidade vem inteiramente do contraste entre as três camadas de fundo (background → surface → surfaceVariant) e, ocasionalmente, de blur (BackdropFilter) em sheets/popovers que precisam se destacar sobre conteúdo rolável por baixo. Não há vocabulário de `box-shadow` estrutural no design system — onde sombra aparece hoje no código (alguns botões/FABs), é incidental, não um token do sistema, e deve ser tratada como dívida a normalizar, não como padrão a expandir.

### Named Rules
**The Flat-By-Default Rule.** Superfícies são planas em repouso. Se algo precisa se destacar, sobe uma camada de tom (surface → surfaceVariant) ou ganha um `BackdropFilter` blur (apenas em sheets/popovers/menus flutuantes sobre conteúdo) — nunca um box-shadow decorativo.

## 5. Components

Confiante e contido: bordas sutis, accent cyan usado com moderação, nada grita pra chamar atenção. Cada componente assume sua camada de tom e para ali.

### Buttons
- **Shape:** radius 12px (rounded.md) para botões de ação primária; pill (999px) para chips/tags.
- **Primary:** fundo `accent` (#5FD3DC no graphite), texto em contraste com o background do tema.
- **Ghost/Secondary:** fundo surfaceVariant, texto secundário.
- **Hover/Focus:** não há hover (touch-first); foco visual é borda accent em inputs.

### Chips (Tags)
- **Style:** fundo na cor semântica em baixa opacidade (~15%), texto na cor semântica plena, radius pill.
- **State:** sem variante "não selecionado" visualmente distinta além da ausência do chip.

### Cards / Containers
- **Corner Style:** radius 16-20px (rounded.lg/xl) para cards de conteúdo (tarefa atrasada, hoje, projetos); 12px para itens de lista densos.
- **Background:** surface (camada 1) sobre background.
- **Shadow Strategy:** nenhuma — ver Elevation. Diferenciação por tom, não sombra.
- **Border:** opcional, branco a ~8-10% de opacidade, só quando o card precisa de borda visível sobre fundo próximo em tom.
- **Internal Padding:** 13px horizontal / 11-12px vertical nos cards compactos da Home; 16-20px em sheets de tela cheia.

### Inputs / Fields
- **Style:** fundo surfaceVariant, sem borda em repouso, radius 10-12px.
- **Focus:** borda accent a ~60% de opacidade, 1.5px.

### Navigation
- **Style:** pílula flutuante ("Liquid Glass") sobre BackdropFilter blur, 5 abas (Navegar/Inbox/Hoje/Em breve/Filtros), ícone + indicador de seleção. FAB expansível acima da pílula para ações rápidas (nova tarefa/projeto/busca).

### Task Tile (componente assinatura)
Linha de tarefa compacta (52-56px), com: checkbox circular à esquerda, título + preview de descrição truncada, metadados (data/prioridade/tags) em linha abaixo, swipe horizontal revela ações (concluir/adiar/excluir) com direction-lock contra scroll vertical, long-press abre menu de contexto compacto com sub-painéis expansíveis.

## 6. Do's and Don'ts

### Do:
- **Do** usar exatamente um accent por tema, em ≤10% da tela.
- **Do** expressar elevação por camada de tom (background → surface → surfaceVariant), nunca por sombra.
- **Do** manter linhas de tarefa compactas (52-56px) — densidade é o ponto, não espaço vazio.
- **Do** restringir caixa-alta + letter-spacing a badges/labels curtos (≤4 palavras).
- **Do** usar BackdropFilter blur apenas em sheets, popovers e menus flutuantes sobre conteúdo rolável — nunca decorativo num card estático.

### Don't:
- **Don't** espalhar múltiplas cores saturadas competindo na mesma tela — isso é o anti-padrão "Todoist genérico colorido demais" que o sistema rejeita explicitamente.
- **Don't** empilhar opções/blocos por item ao estilo Notion — cada linha de tarefa tem affordances limitadas e deliberadas (swipe, long-press), não um menu denso permanente.
- **Don't** adicionar confete, badges de gamificação, streaks ou sons de recompensa — fricção mínima e calma acima de qualquer reforço positivo decorativo.
- **Don't** usar `box-shadow` decorativo em cards ou botões em repouso — é dívida visual a remover, não padrão a expandir.
- **Don't** trocar de família tipográfica pra criar hierarquia — peso e tamanho resolvem isso.
- **Don't** usar `border-left`/`border-right` colorido como stripe decorativo em cards ou listas.
