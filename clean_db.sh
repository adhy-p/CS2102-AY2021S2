#!/bin/bash

tables=(
administrators       
buys                 
cancels              
course_areas         
course_packages      
courses              
credit_cards         
customers            
employees            
full_time_employees  
full_time_instructors
instructors          
managers             
offerings            
part_time_employees  
part_time_instructors
pay_slips            
redeems              
registers            
rooms                
sessions             
specializes          
)

for i in ${tables[@]}; do
    echo "drop table $i cascade;"
done
