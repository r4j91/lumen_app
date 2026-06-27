# Product

## Register

product

## Users

Uso pessoal (o próprio desenvolvedor). Gerenciamento diário de tarefas e projetos — abre o app várias vezes ao dia, em momentos curtos, pra checar o que precisa fazer agora, marcar tarefas como concluídas, ou organizar o que vem a seguir. Contexto de uso: mobile-first (iOS/Android via Flutter), também desktop/web. Sessões curtas e frequentes, não uso prolongado.

## Product Purpose

Alternativa pessoal ao Todoist/Things 3 — gerenciador de tarefas com projetos, etiquetas, datas/horas, recorrência, subtarefas. Sucesso é fricção mínima: abrir o app, ver o que importa hoje, completar ou adiar rápido, fechar. Reconstrução em Flutter (anteriormente PWA em React/Tailwind).

## Brand Personality

Calmo, denso, rápido. Voz visual sóbria — sem confete, badges de gamificação, ou decoração gratuita. Densidade de informação alta mas organizada (linhas de tarefa compactas ~52-56px), não minimalista vazio. Velocidade de interação importa mais que ornamento.

## Anti-references

- Todoist genérico colorido demais (cores saturadas em todo canto, perde hierarquia)
- Notion (denso de blocos, lento de navegar, excesso de opções por item)
- Apps de produtividade gamificados (confete, streaks, badges, sons de recompensa)
- Glassmorphism decorativo sem propósito (blur só onde já é convenção de sistema: sheets/popovers)

## Design Principles

1. Fricção mínima acima de tudo — cada toque extra pra completar uma ação cotidiana é uma falha de design
2. Densidade organizada, não densidade caótica — muita informação por tela, mas com hierarquia tipográfica e espaçamento que guiam o olho
3. Dark mode como padrão e cidadão de primeira classe, não um tema alternativo mal cuidado
4. Microinterações sutis carregam a sensação de qualidade (swipe, long-press, animações de conclusão) — sem serem o ponto central
5. Consistência entre telas-irmãs (Hoje/Inbox/Em breve/Filtros) é não-negociável — usuário não deve notar qual tela está, só o que ela mostra

## Accessibility & Inclusion

Sem WCAG level formal exigido. Boas práticas gerais aplicadas com bom senso: área de toque adequada em alvos interativos, contraste legível em texto sobre fundo escuro, reduced motion respeitado onde fizer sentido (sem exigência de bandeira de acessibilidade dedicada no momento).
