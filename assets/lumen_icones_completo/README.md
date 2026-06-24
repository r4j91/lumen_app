# Lumen — Pacote de Ícones do App

Conceito: "Camadas Empilhadas" — três losangos arredondados sobrepostos,
do mais escuro (base) ao mais claro (topo), dentro de um squircle escuro
com moldura biselada iluminada de cima, no estilo Things 3.

## Variante padrão do app

**grafite/** — esta é a variante oficial/padrão do Lumen. Use esta para
o ícone real do app nas lojas (iOS App Store e Google Play) e nos
arquivos de build (Assets.xcassets, mipmap do Android).

## Outras variantes (mesma forma, paleta diferente)

- cinza_escuro
- cinza_medio
- cinza_claro
- branco
- carvao
- azul_nevoa
- azul_oceano
- titanio
- fosco

Cada pasta de variante contém:

```
<variante>/
├── lumen_icon_<variante>.svg     ← arquivo vetorial mestre (editável)
├── icon_1024.png                  ← PNG de alta resolução (App Store)
├── icon_512.png
├── ios/
│   ├── icon_1024.png
│   ├── icon_180.png
│   ├── icon_167.png
│   ├── icon_152.png
│   ├── icon_144.png
│   ├── icon_120.png
│   ├── icon_114.png
│   ├── icon_100.png
│   ├── icon_87.png
│   ├── icon_80.png
│   ├── icon_76.png
│   ├── icon_72.png
│   ├── icon_60.png
│   ├── icon_58.png
│   ├── icon_57.png
│   ├── icon_50.png
│   ├── icon_40.png
│   ├── icon_29.png
│   └── icon_20.png
└── android/
    ├── icon_mdpi_48.png
    ├── icon_hdpi_72.png
    ├── icon_xhdpi_96.png
    ├── icon_xxhdpi_144.png
    ├── icon_xxxhdpi_192.png
    └── icon_playstore_512.png
```

## Como usar no Xcode (iOS)

1. Abra `Assets.xcassets` no projeto Lumen
2. Selecione (ou crie) o `AppIcon` set
3. Arraste cada PNG da pasta `ios/` para o slot de tamanho correspondente
   (o nome do arquivo já indica o tamanho em pixels)
4. Para simplificar, o Xcode 14+ aceita um único `icon_1024.png` — nesse
   caso ele gera os demais tamanhos automaticamente

## Como usar no Android

1. Copie os arquivos de `android/` para as pastas `res/mipmap-<density>/`
   correspondentes no projeto, renomeando para `ic_launcher.png`:
   - `icon_mdpi_48.png` → `res/mipmap-mdpi/ic_launcher.png`
   - `icon_hdpi_72.png` → `res/mipmap-hdpi/ic_launcher.png`
   - `icon_xhdpi_96.png` → `res/mipmap-xhdpi/ic_launcher.png`
   - `icon_xxhdpi_144.png` → `res/mipmap-xxhdpi/ic_launcher.png`
   - `icon_xxxhdpi_192.png` → `res/mipmap-xxxhdpi/ic_launcher.png`
2. `icon_playstore_512.png` é o arquivo para upload na Play Store
   (Configuração da loja → Ícone do app)

## Paleta da variante padrão (Grafite)

- Fundo: `#2B2B30` → `#1C1C20` → `#121215`
- Moldura externa: `#F0F0F2` (luz no topo) → `#3A3A40` (sombra embaixo)
- Camada de trás: `#5C5C62` → `#222226`
- Camada do meio: `#D6D6DA` → `#7A7A80`
- Camada da frente: `#FFFFFF` → `#F2F2F4` → `#C7C7CC`
