- postman is instaled using snap store, found a postman-db.sh script that does the installation at SanderTheDragon

## Pre-requisites

Install python, you can do so by using pyenv to help manage both  python versions and virtual environments.
We recommend you create a virtualenvirtonment.

Install the python dependencies
pip install -r requirements/dev.txt
Install the ansible dependencies
ansible-galaxy install -r requirements.yml

`ansible-playbook  playbook.yml -c=local -i inventoryFile -b -K
`


** We use the shell scripts to do normal environment and tool support to run the playbook and then it calls the ansible scripts to setup everything else.
