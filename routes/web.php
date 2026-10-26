<?php

use Illuminate\Support\Facades\Route;

Route::get('/', function () {
    return view('welcome');
});

// health check for deployments: is the app up, and can it reach its database?
Route::get('/health', function () {
    return [
        'status'            => 'ok',
        'app'               => config('app.name'),
        'environment'       => app()->environment(),
        'php'               => PHP_VERSION,
        'users_in_database' => \App\Models\User::count(),
    ];
});
