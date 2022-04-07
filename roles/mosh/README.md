# ansible-setup-computer

Really simple role that sets up a fresh computer.

## Notes

- After the SSH private key is put in place, you may have to generate a public key like so:

  ```sh
  $ ssh-keygen -y -f ~/.ssh/id_rsa > ~/.ssh/id_rsa.pub
  Enter passphrase:
  ```

## License

MIT
