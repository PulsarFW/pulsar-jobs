<div align="center">

<img src="https://r2.fivemanage.com/GPYOH8Hq4GPyAY7czrgLe/pulsarbanner.png" alt="Pulsar Framework" width="100%" />

<br/>

# PULSAR-JOBS

### Employment system — job/grade assignment, duty toggling, salary payout, and the default job catalog

<br/>

![Lua](https://img.shields.io/badge/Lua_5.4-2C2D72?style=flat-square&logo=lua&logoColor=white)
![FiveM](https://img.shields.io/badge/FiveM-F40552?style=flat-square)

<br/>

<sub>Enjoy the framework? A coffee helps keep active development, hardening, and support going.</sub>

<a href="https://buymeacoffee.com/pulsarframework"><img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" alt="Buy Me A Coffee" style="height: 50px !important;width: 180px !important;" /></a>

<br/>

[Overview](#overview) · [Dependencies](#dependencies)

</div>

---

## Overview

Registers `plsr.Jobs` — `GiveJob`/`RemoveJob`, on/off-duty toggling with salary accrual, and job permission checks (`plsr.Jobs.Permissions:HasJob`). `config/defaultJobs/` seeds the starting job catalog; `config/spawns.lua` covers job-specific spawn points. Also includes a standalone metal-detector treasure-hunting mechanic.

> [!WARNING]
> The character's `Jobs` field is a JSON array stored on `characters.data`. Every offline-character write path here goes through `JSON_SET` — pass values through `CAST(? AS JSON)`, not a raw `json.encode`'d string parameter, or the field silently corrupts into a JSON string instead of an array.

---

## Dependencies

- `pulsar_core` — framework core
- `pulsar_characters` — job data lives on the character's `DataStore`
- `pulsar_pwnzor` — anti-cheat check loaded alongside every resource

---

## License

This resource is free to use and modify under the [Pulsar Framework License](LICENSE.md). Redistribution is welcome as long as it stays free — selling this resource or any derivative of it requires written permission from the Pulsar Framework team.

---

<div align="center">

![Pulsar Framework](https://img.shields.io/badge/Pulsar-Framework-7c3aed?style=flat-square)
![Built for FiveM](https://img.shields.io/badge/Built_for-FiveM-F40552?style=flat-square)

</div>
