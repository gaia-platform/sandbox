# MQTT Communication Specification Doc

## Table of contents

| `[demo-name]`    | Links to simulation section                |
| ---------------- | ------------------------------------------ |
| `factory`        | [AMR Simulations](#factory)                |
| `access_control` | [Building Access Control](#access_control) |

## General Info

MQTT topic template: `[UUID]/[demo-name]/[topic]`

| When...                               | Use prefix                          |
| ------------------------------------- | ----------------------------------- |
| Subscribing                           | `[sandboxUUID]`                     |
| Publishing to a Gaia app              | `[appUUID]`                         |
| Publishing to the Sandbox Coordinator | `sandbox_coordinator/[sandboxUUID]` |

---

# AMR Simulations (`factory`) <a id="factory"></a>

## Sandbox subscribes to

| Topic name                | Example Payload                             | Description                                                  |
| ------------------------- | ------------------------------------------- | ------------------------------------------------------------ |
| `[bot_id]/move_location`  | `2`                                         | Instruct `[bot_id]` to move to given `nav_node`              |
| `[bot_id]/pickup_payload` | `3`                                         | Pickup next payload (could be widget or pallet) from given `area` index |
| `[bot_id]/drop_payload`   | `5`                                         | Drop payload at given `area` index                           |
| `[bot_id]/status_request` | [`[status_item]`](#factory_bot_status_item) | Request for bot status                                       |



## Sandbox publishes

| Topic name                    | Payload        | Description                                                  |
| ----------------------------- | -------------- | ------------------------------------------------------------ |
| `order_arrived`               | `true`         | When a new pallet arrives in Inbound                         |
| `unpacked_pallet`             | `true`         | When a pallet is unpacked into the buffer area               |
| `processed_widget`            | `true`         | When a widget makes it to PL End                             |
| `[bot_id]/did_command`        | `true`/`false` | Complete/incomplete feedback on last command                 |
| `bots/[bot_id]/crashed`       | `"buffer"`     | Reports a bot with ID crashed while going to goal location `payload` |
| `bots/[bot_id]/cant_navigate` | `"buffer"`     | Response from bot when it can't complete a navigation because either the path couldn't be generated or if the end location was blocked |

 - `[robot-id]/info/[status_item]` (Robot status)

| <span id="factory_bot_status_item">`[status_item]`</span> | Example Payload | Notes                                                        |
| --------------------------------------------------------- | --------------- | ------------------------------------------------------------ |
| `id`                                                      | `"b-123"`       |                                                              |
| `type`                                                    | `1`             | See [enums](#bot_type)                                       |
| `goal_location`                                           | `1`             | [^](#bot_goal_location)                                      |
| `world_location`                                          | `(523,456)`     | Will simply use in-game pixel location data, but IRL should use grid coordinates |
| `charge_level`                                            | `0.76`          |                                                              |
| `is_charching`                                            | `false`         |                                                              |
| `speed_squared`                                           | `0.64`          | Computationally less intensive to return the square magnitude of the velocity vector |

* `info/[factory_status_item]` (Factory status)

| `[factory_status_item]` | Example Payload | Notes |
| ----------------------- | --------------- | ----- |
|                         |                 |       |
|                         |                 |       |
|                         |                 |       |



## Enumerations

| Enum name                                           | Enum values                        | Notes                                                        |
| --------------------------------------------------- | ---------------------------------- | ------------------------------------------------------------ |
| <span id="bot_type">`type`</span>                   | `0 = bumblebee`<br />`1 = stacker` | The two types of AMRs defined                                |
| <span id="bot_goal_location">`goal_location`</span> | Dependent on factory layout        | Each location in a factory is assigned a number which corresponds to an in-game coordinate |

---

# Access Control (`access_control`) <a id="access_control"></a>

## Sandbox subscriptions

| Topic name                     | Expected Payload                            | Description                                                  |
| ------------------------------ | ------------------------------------------- | ------------------------------------------------------------ |
| `init`                         | too much to output here (subject to change) | Verbose output of everything. Used to create initial state   |
| `alert`                        | `[error_message]`                           | Error message                                                |
| `[person_id]/move_to_building` | `[building_id]` or `""`                     | When a person moves in/out a building. Use empty string to leave building |
| `[person_id]/move_to_room`     | `[building_id],[room_id]`                   | When a person moves in/out a room. Payload is comma separated |
| `[person_id]/scan`             | `[scan_type]`                               | When a person's scan status changes. N/A for `"face"` and `"leaving"`. See [enum](#ac_scan_type) |
|                                |                                             |                                                              |

## Sandbox publishes

* `time`
  * Simulated world time in minutes
  * Payload: `[time-in-minutes]`
* `scan`
  * Payload: 

```json
{
    "scan_type": [scan_type],
    "person_id": [person_id],
    "building_id": [building_id],
    "room_id": [room_id]
}
```

## Enumerations

| Enum name                                  | Enum values                                                  | Notes |
| ------------------------------------------ | ------------------------------------------------------------ | ----- |
| <span id="ac_scan_type">`scan_type`</span> | `"badge"`<br />`"face"`<br />`"leaving"`<br />`"vehicle_departing"`<br />`"vehicle_entering"`<br />`"leaving_wifi"`<br />`"joining_wifi"` |       |
|                                            |                                                              |       |

##### 
