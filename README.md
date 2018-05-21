# OC-BrewingManager
A brewing stand manager for OpenComputers.

_This is still in beta_, the blaze powder must be put manually into the brewing stand and there's no signal when the glass bottle chest is empty.

# Computers configurations

### Computer client
- 1x EEPROM Lua BIOS
- 1x Wireless Network Card (Tier 1 min)
- 1x Graphics Card (Only Tier 3 for the moment, Tier 2 should be supported in the future)
- 1x CPU (Tier 1 min)
- 1x Screen (Tier 3, same as the graphics card)
- At least 384k of RAM
- An installation of OpenOS

### Robots (x2)
- 1x EEPROM Lua BIOS
- 1x CPU (Tier 1 should be enough)
- 1x Inventory Upgrade
- 1x Inventory Controller Upgrade
- 1x Keyboard
- 1x Screen (Tier 1 min)
- 1x Wireless Network Card (Tier 1 min)
- At least 384k of RAM should be enough
- An installation of OpenOS

# How to Build
The build consists in two layers:

### First layer
![First layer](https://preview.ibb.co/en6b38/first_layer.png)

The "Adventure Core" robot must be facing the Brewing Stand and has the "blaze and bottle server.lua" file

### Second layer
![Second layer](https://preview.ibb.co/g3ukwT/second_layer.png)

The "Autobot" robot must be facing the chest and has the "ingredient_server.lua" file

### All layers
![All layers](https://preview.ibb.co/iKhuqo/2018_05_21_15_24_35.png)

# To-Do List
- Show Blaze Powder and Glass Powder levels
- Automatically refill the Blaze Powder
- Properly handle missing Blaze Powder and Glass Powder
- Check if it works with 1 or 2 bottles left
- Use the adapter
- Adapter: check if there's a potion in the queue and the brewing time returned by the adapter hasn't changed in one second to detect if the brewing stand is stuck (if the ingredient can't be brewed into the potions)
- Support Tier 2 screen/GPU
