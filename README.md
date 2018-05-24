# sensu-api-canned

sensu-api-canned maps a folder structure (`api`) to API responses.

## Installation

```
npm install
```

## Usage

```
npm start
```

The canned API listens to the port **4567**.

## Generating data

It's possible to regenerate the data for certain objects.

### Clients

```
./generate.rb clients 100
```

**N.B.** You will also need to regenerate the events.

### Events

```
./generate.rb events 10
```
