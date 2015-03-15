# Usage

Install ruby

```sh
> curl -sSL https://get.rvm.io | bash -s stable
> rvm install ruby
```

Install dependencies

```sh
> bundle install
```

Rename `aws.yml.example` to `aws.yml` 

```sh
> cp aws.yml.example aws.yml
```

Adjust credentials in aws.yml
Adjust `config.yml`

Run the script:

```
> ruby run.rb
```
