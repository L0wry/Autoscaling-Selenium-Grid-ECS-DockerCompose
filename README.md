# Turbo Charging Your Selenium Grid

## Concept 
Sick of maintaining your selenium infrastructure?

You're not alone.

Which is why I created the following repository to spin up the latest selenium test infrastructure, and tear it down when your day is over giving you 0 maintenance and lower costs overall.

## Implementation
* AWS
* AWS - Elastic Container Service
* Docker
* Docker Compose
* Selenium

## Getting up and running

    Pull the Repo

    Populate the environment variables in the create-grid.sh

    Checkout the docker-compose.yml and update the memory and cpu allocation as per your instance size

    Update the ecs-params.yml as per your instance capabilities

    Run the script

    Have you CI tool run the script every morning when you want to spin up your grid.


## Notes:

     This will tear down your grid at 8pm, feel free to change the cron job

     I have found this to be most reliable when using a VPC in a PUBLIC subnet with no load balancer. When I introduced a load balancer I was seeing lots of time outs in my UI tests.

    At the time of writing this I am not using autoscaling groups to spin up an instance because I can't assign the machine an elastic IP which I need to have white-listed by my applications under test

    I have added another script stop-grid-task.sh to reset the selenium Task. All my UI tests now depend on this to give the grid a clean state and clear up any lost grid sessions before they run. I have found this has been very useful in improving stability.




