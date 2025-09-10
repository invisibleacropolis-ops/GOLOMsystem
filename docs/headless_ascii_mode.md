# Headless ASCII Mode

The project can be executed without a graphical window using the built-in ASCII renderer. The mode mirrors the normal GUI behavior by running all runtime services and actors while rendering the world to the terminal.

## Running

```
godot4 --headless --path .
```

Module tests run first; if successful the ASCII grid will begin updating in the terminal. Use the following commands to interact:

- `w`, `a`, `s`, `d` – move the player actor when it is their turn.
- `quit` – exit the simulation.

The renderer prints the grid every half second, including actor positions (`@`). Other AI-driven actors continue to move during their turns, matching behavior in the GUI version.
