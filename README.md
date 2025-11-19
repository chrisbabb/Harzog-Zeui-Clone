# Harzog-Zeui-Clone

A local multiplayer RTS game where players control transformer heroes and build support units in a toroidal (wrap-around) world.

## Features

### Core Gameplay
- **1-4 Player Split-Screen**: Supports 1-4 human players and/or AI opponents
- **Transformer Heroes**: Each player controls a hero that can transform between:
  - Humanoid form (ground unit)
  - Plane form (air unit)
- **Base Building**: Build and manage support units from your main base
- **Toroidal World**: Map wraps around in all directions (north/south/east/west)
- **Team-Based or Free-For-All**: Players with the same color are teammates

### Unit Types (Planned)
- Ground units: Basic Soldier, Tank, Peon
- Anti-air units: Missile Soldier, Missile Tank
- Turrets: Gun Turret, Missile Turret, Death Turret
- Support: Peons for capturing mini-bases

### AI Difficulty Levels
- **Easy**: Fixed build orders, poor focus fire
- **Normal**: Adaptive composition, reasonable tactics
- **Hard**: Strong counters, excellent coordination

### Game Modes
- Free-for-all (all different colors)
- Team play (shared colors)
- Human vs AI
- AI vs AI spectator mode

## Technology Stack

- **Engine**: Godot 4.3
- **Language**: GDScript
- **Platform**: PC (Windows/Linux/Mac)
- **Graphics**: 2D top-down perspective

## Project Structure

```
Harzog-Zeui-Clone/
├── assets/                 # Game assets
│   ├── audio/             # Music and sound effects
│   └── sprites/           # Textures and sprites
├── scenes/                # Godot scenes
│   ├── game/              # Game world and gameplay scenes
│   ├── ui/                # Menu and UI scenes
│   ├── units/             # Unit scenes
│   └── buildings/         # Building scenes
├── scripts/               # GDScript files
│   ├── autoloads/         # Global singleton scripts
│   ├── game/              # Game logic
│   ├── units/             # Unit behavior
│   ├── ai/                # AI systems
│   ├── ui/                # UI controllers
│   └── utils/             # Utility functions
├── project.godot          # Godot project configuration
├── CLAUDE.md              # AI assistant development guide
└── README.md              # This file
```

## Getting Started

### Prerequisites

- **Godot 4.3 or later**: Download from [godotengine.org](https://godotengine.org/)

### Installation

1. **Clone the repository**:
   ```bash
   git clone <repository-url>
   cd Harzog-Zeui-Clone
   ```

2. **Open in Godot**:
   - Launch Godot Engine
   - Click "Import"
   - Navigate to the project folder
   - Select `project.godot`
   - Click "Import & Edit"

3. **Run the game**:
   - Press F5 in the Godot editor, or
   - Click the "Play" button in the top-right corner

### Controls (Default - Player 1)

**Keyboard + Mouse**:
- **W/A/S/D**: Move
- **Left Mouse**: Attack
- **Space**: Transform (Humanoid ↔ Plane)
- **E**: Pickup packaged units (when in plane mode over base)
- **R**: Deploy units (when in plane mode)
- **B**: Open build menu
- **Enter**: Confirm
- **Escape**: Cancel/Back

**Controller** (Players 2-4):
- **D-Pad / Left Stick**: Move
- **Right Stick**: Aim
- **A Button**: Attack/Confirm
- **B Button**: Transform/Cancel
- **X Button**: Pickup
- **Y Button**: Deploy
- **Left Shoulder**: Build menu

Controls can be remapped in the Settings menu.

## Development Status

### ✅ Completed
- Project structure and Godot 4 setup
- Main menu system
- Settings menu (video and audio)
- Match setup screen (player/AI/team configuration)
- Toroidal world utilities
- Split-screen system (1-4 players)
- Input management for multiple players/controllers
- AI difficulty framework
- Unit base class and state machine
- Global manager systems (Game, Input, Audio, Settings, AI)

### 🚧 In Progress
- Unit implementation (soldiers, tanks, turrets)
- Transformer hero mechanics
- Building and production systems
- AI behavior implementation

### 📋 Planned
- Pathfinding for ground units
- Combat and projectile systems
- Mini-base capture mechanics
- Visual effects and animations
- Sound effects and music
- Unit portraits and UI polish
- Win/loss screens
- Replay system

## Game Systems

### Toroidal World

The game world wraps around seamlessly:
- Moving off the east edge appears on the west edge
- Moving off the north edge appears on the south edge
- All distance calculations consider wrap-around
- Cameras handle wrapping correctly for split-screen

Implementation: `scripts/utils/toroidal_world.gd`

### Split-Screen

Automatically configures viewports based on player count:
- **1 Player**: Full screen
- **2 Players**: Horizontal split (left/right)
- **3-4 Players**: Quad split (2x2 grid)

Implementation: `scripts/game/game_world.gd`

### AI System

AI opponents operate at three difficulty levels with different:
- Decision-making frequencies
- Build order adaptability
- Focus fire and coordination
- Strategic awareness

Implementation: `scripts/autoloads/ai_manager.gd`

### State Machine

Units use a state-based behavior system:
- **IDLE**: Awaiting orders
- **MARCHING_TO_TARGET**: Moving toward objective
- **ENGAGING_TARGET**: In combat
- **DEAD**: Unit destroyed

Stances:
- **HOLD_POSITION**: Stay in place, only attack in range
- **ADVANCE**: Move toward enemies/objectives

Implementation: `scripts/units/unit_base.gd`

## Contributing

This is a learning/demonstration project. See `CLAUDE.md` for detailed development guidelines and conventions.

### Code Style

- Follow GDScript style guide
- Use typed GDScript where possible
- Document classes and functions with comments
- Use meaningful variable names

### Commit Messages

Follow conventional commits format:
```
<type>(<scope>): <subject>

Examples:
feat(units): add tank unit with anti-ground attacks
fix(ai): correct target prioritization for air units
docs(readme): update installation instructions
```

## License

[To be determined]

## Credits

- Developed with Godot Engine
- Project created for learning game development and AI systems

## Support

For issues, questions, or suggestions:
1. Check the `CLAUDE.md` file for detailed documentation
2. Review existing issues in the repository
3. Create a new issue with a clear description

---

**Current Version**: 0.1.0-alpha
**Last Updated**: 2025-11-19
