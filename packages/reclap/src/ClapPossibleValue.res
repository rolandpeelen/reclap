type t = {
  name: string,
  help: option<string>,
  aliases: array<string>,
  hidden: bool,
}

let make = name => {name, help: None, aliases: [], hidden: false}

let help = (possibleValue, help) => {...possibleValue, help: Some(help)}

let alias = (possibleValue, alias) => {
  ...possibleValue,
  aliases: Array.concat(possibleValue.aliases, [alias]),
}

let hide = possibleValue => {...possibleValue, hidden: true}

let matches = (possibleValue, input) =>
  possibleValue.name == input || possibleValue.aliases->Array.includes(input)
